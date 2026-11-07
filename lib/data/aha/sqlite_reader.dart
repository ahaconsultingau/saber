import 'dart:convert';
import 'dart:typed_data';

/// Aha! copy: a small, read-only reader for SQLite database files, enough to
/// read every row of one table. Noteshelf stores each page's ink in a SQLite
/// file; reading it here avoids adding a native database library to the app.
///
/// Follows the published file format (https://sqlite.org/fileformat.html):
/// table b-trees, record encoding and overflow pages. Indexes, WAL files and
/// writing are not supported.
class SqliteReader {
  new(this._bytes)
    : _data = ByteData.sublistView(_bytes),
      _pageSize = _readPageSize(_bytes),
      _usable = _readPageSize(_bytes) - (_bytes.length > 20 ? _bytes[20] : 0) {
    if (_bytes.length < 100 ||
        ascii.decode(_bytes.sublist(0, 15), allowInvalid: true) !=
            'SQLite format 3') {
      throw const FormatException('Not an SQLite database');
    }
  }

  final Uint8List _bytes;
  final ByteData _data;
  final int _pageSize;
  final int _usable;

  static int _readPageSize(Uint8List bytes) {
    if (bytes.length < 18) return 4096;
    final size = (bytes[16] << 8) | bytes[17];
    return size == 1 ? 65536 : size;
  }

  /// Every row of [table], as column name → value (int, double, String,
  /// Uint8List or null). Columns a row doesn't store (added to the table
  /// later) are left out.
  List<Map<String, Object?>> readTable(String table) {
    final master = _readTree(1);
    for (final row in master) {
      // sqlite_master: type, name, tbl_name, rootpage, sql
      if (row.length < 5 || row[0] != 'table' || row[1] != table) continue;
      final columns = _columnNames(row[4] as String? ?? '');
      return [
        for (final values in _readTree(row[3] as int))
          {
            for (var i = 0; i < values.length && i < columns.length; i++)
              columns[i]: values[i],
          },
      ];
    }
    return const [];
  }

  /// Column names from a CREATE TABLE statement.
  static List<String> _columnNames(String sql) {
    final open = sql.indexOf('('), close = sql.lastIndexOf(')');
    if (open < 0 || close <= open) return const [];
    final body = sql.substring(open + 1, close);
    final names = <String>[];
    var depth = 0, start = 0;
    for (var i = 0; i <= body.length; i++) {
      final ch = i < body.length ? body[i] : ',';
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        final part = body.substring(start, i).trim();
        start = i + 1;
        if (part.isEmpty) continue;
        final first = part.split(RegExp(r'\s+')).first;
        final upper = first.toUpperCase();
        if (const {
          'PRIMARY',
          'UNIQUE',
          'CHECK',
          'FOREIGN',
          'CONSTRAINT',
        }.contains(upper)) {
          continue;
        }
        names.add(first.replaceAll(RegExp('^["`\\[]|["`\\]]\$'), ''));
      }
    }
    return names;
  }

  /// The records of the table b-tree rooted at [page], in rowid order.
  List<List<Object?>> _readTree(int page) {
    final rows = <List<Object?>>[];
    final stack = [page];
    final seen = <int>{};
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (!seen.add(p)) continue; // a damaged file must not loop
      final base = (p - 1) * _pageSize;
      final header = p == 1 ? base + 100 : base;
      if (header + 8 > _bytes.length) continue;
      final type = _bytes[header];
      final cellCount = _data.getUint16(header + 3);
      if (type == 0x05) {
        // Interior table page: children in order, then the right-most.
        final children = <int>[];
        for (var i = 0; i < cellCount; i++) {
          final cell = base + _data.getUint16(header + 12 + i * 2);
          children.add(_data.getUint32(cell));
        }
        children.add(_data.getUint32(header + 8));
        stack.addAll(children.reversed);
      } else if (type == 0x0D) {
        for (var i = 0; i < cellCount; i++) {
          final cell = base + _data.getUint16(header + 8 + i * 2);
          rows.add(_readLeafCell(cell));
        }
      }
    }
    return rows;
  }

  List<Object?> _readLeafCell(int offset) {
    var pos = offset;
    final (payloadLength, n1) = _varint(pos);
    pos += n1;
    final (_, n2) = _varint(pos); // rowid
    pos += n2;
    final payload = _payload(pos, payloadLength);
    return _record(payload);
  }

  /// The payload of a cell, following overflow pages if it doesn't fit.
  Uint8List _payload(int pos, int length) {
    final maxLocal = _usable - 35;
    if (length <= maxLocal) {
      return Uint8List.sublistView(_bytes, pos, pos + length);
    }
    final minLocal = ((_usable - 12) * 32 ~/ 255) - 23;
    var local = minLocal + (length - minLocal) % (_usable - 4);
    if (local > maxLocal) local = minLocal;
    final out = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(_bytes, pos, pos + local));
    var remaining = length - local;
    var next = _data.getUint32(pos + local);
    final seen = <int>{};
    while (remaining > 0 && next != 0 && seen.add(next)) {
      final base = (next - 1) * _pageSize;
      if (base + 4 > _bytes.length) break;
      final take = remaining < _usable - 4 ? remaining : _usable - 4;
      out.add(Uint8List.sublistView(_bytes, base + 4, base + 4 + take));
      remaining -= take;
      next = _data.getUint32(base);
    }
    return out.takeBytes();
  }

  List<Object?> _record(Uint8List p) {
    final data = ByteData.sublistView(p);
    final (headerSize, n) = _varintIn(p, 0);
    var h = n;
    final types = <int>[];
    while (h < headerSize) {
      final (t, m) = _varintIn(p, h);
      types.add(t);
      h += m;
    }
    var pos = headerSize;
    final values = <Object?>[];
    for (final t in types) {
      switch (t) {
        case 0:
          values.add(null);
        case 1:
          values.add(data.getInt8(pos));
          pos += 1;
        case 2:
          values.add(data.getInt16(pos));
          pos += 2;
        case 3:
          final v = (p[pos] << 16) | (p[pos + 1] << 8) | p[pos + 2];
          values.add(v >= 0x800000 ? v - 0x1000000 : v);
          pos += 3;
        case 4:
          values.add(data.getInt32(pos));
          pos += 4;
        case 5:
          final hi = data.getInt16(pos);
          final lo = data.getUint32(pos + 2);
          values.add(hi * 0x100000000 + lo);
          pos += 6;
        case 6:
          values.add(data.getInt64(pos));
          pos += 8;
        case 7:
          values.add(data.getFloat64(pos));
          pos += 8;
        case 8:
          values.add(0);
        case 9:
          values.add(1);
        default:
          if (t >= 12 && t.isEven) {
            final len = (t - 12) ~/ 2;
            values.add(Uint8List.fromList(p.sublist(pos, pos + len)));
            pos += len;
          } else if (t >= 13) {
            final len = (t - 13) ~/ 2;
            values.add(
              utf8.decode(p.sublist(pos, pos + len), allowMalformed: true),
            );
            pos += len;
          } else {
            values.add(null);
          }
      }
    }
    return values;
  }

  (int, int) _varint(int pos) => _varintIn(_bytes, pos);

  static (int, int) _varintIn(Uint8List b, int pos) {
    var value = 0;
    for (var i = 0; i < 8; i++) {
      final byte = b[pos + i];
      value = (value << 7) | (byte & 0x7f);
      if (byte < 0x80) return (value, i + 1);
    }
    return ((value << 8) | b[pos + 8], 9);
  }
}
