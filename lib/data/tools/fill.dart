import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:sbn/tool_id.dart';

/// Aha! copy: the paint bucket. A tap inside a closed outline fills it with
/// solid colour, under the ink.
///
/// The fill is saved as ordinary straight shape-pen strokes (one per row),
/// so the standard Saber apps show it. Shape-pen strokes are drawn before
/// the pens, so the fill sits under writing.
class FillTool extends Tool {
  new({this.color = Colors.blue});

  Color color;

  static var currentFill = FillTool();

  @override
  ToolId get toolId => ToolId.shapePen;

  /// The size of one fill cell, in page units (a page is 1000 units wide).
  static const cell = 2.0;

  /// The thickness of each row of fill: a little more than a cell so rows
  /// overlap without gaps.
  static const rowWidth = cell * 1.5;

  /// How far gaps in an outline are closed, in cells, tried smallest first.
  /// 6 cells closes gaps of about 24 units, roughly 5 mm on an A4 page.
  static const gapSteps = [0, 1, 2, 3, 4, 6];

  /// A fill may not cover more than this share of the page: beyond it, the
  /// colour has escaped through a gap.
  static const maxShareOfPage = 0.5;

  /// Whether [stroke] is a row of fill made by this tool.
  static bool isFillStroke(Stroke stroke) =>
      stroke.toolId == ToolId.shapePen &&
      stroke is! CircleStroke &&
      stroke is! RectangleStroke &&
      !stroke.pressureEnabled &&
      (stroke.options.size - rowWidth).abs() < 0.01 &&
      stroke.inputPoints.length <= 3 &&
      stroke.inputPoints.every((p) => p.dy == stroke.inputPoints.first.dy);

  /// Works out the fill for a tap at [tap] on [page], drawn with [color].
  /// Earlier fill inside the area is listed in [FillResult.replaced].
  static Future<FillResult> fill({
    required EditorPage page,
    required int pageIndex,
    required Offset tap,
    required Color color,
  }) async {
    final grid = await FillGrid.rasterise(page.size, page.strokes);
    final region = grid.regionAt(tap);
    if (region.outcome != FillOutcome.filled) {
      return FillResult(region.outcome, const [], const []);
    }

    final strokes = [
      for (final (y, x0, x1) in region.runs)
        _row(
          y: (y + 0.5) * cell,
          left: x0 * cell,
          right: (x1 + 1) * cell,
          color: color.withAlpha(255),
          page: page,
          pageIndex: pageIndex,
        ),
    ];
    final replaced = [
      for (final s in page.strokes)
        if (isFillStroke(s) && region.contains(_middle(s))) s,
    ];
    return FillResult(FillOutcome.filled, strokes, replaced);
  }

  static Offset _middle(Stroke s) {
    final p = s.inputPoints;
    return Offset((p.first.dx + p.last.dx) / 2, p.first.dy);
  }

  static Stroke _row({
    required double y,
    required double left,
    required double right,
    required Color color,
    required EditorPage page,
    required int pageIndex,
  }) {
    // Round ends stick out by half the row's width: start and end inside.
    var start = left + rowWidth / 2, end = right - rowWidth / 2;
    if (end < start) start = end = (left + right) / 2;
    return Stroke(
      color: color,
      pressureEnabled: false,
      options: StrokeOptions(
        size: rowWidth,
        thinning: 0,
        smoothing: 0,
        streamline: 0,
        simulatePressure: false,
        start: StrokeEndOptions.start(taperEnabled: false),
        end: StrokeEndOptions.end(taperEnabled: false),
        isComplete: true,
      ),
      pageIndex: pageIndex,
      page: page,
      toolId: ToolId.shapePen,
    )..addPoints([Offset(start, y), Offset(end, y), Offset(end, y)]);
  }
}

enum FillOutcome {
  /// The area was filled.
  filled,

  /// The tap was on a line, not inside a shape.
  onLine,

  /// The outline has a gap too big to close: the colour would escape.
  open,
}

class FillResult {
  const new(this.outcome, this.strokes, this.replaced);

  final FillOutcome outcome;

  /// The new rows of fill.
  final List<Stroke> strokes;

  /// Earlier fill inside the same area, which the new fill replaces.
  final List<Stroke> replaced;
}

/// The page as a grid of cells, each either ink or clear.
class FillGrid {
  new(this.width, this.height, this.ink);

  final int width, height;

  /// 1 where there is ink.
  final Uint8List ink;

  /// Draws [strokes] (except highlighter marks and earlier fill) into a grid
  /// covering [pageSize].
  static Future<FillGrid> rasterise(Size pageSize, List<Stroke> strokes) async {
    const cell = FillTool.cell;
    final width = max(1, (pageSize.width / cell).ceil());
    final height = max(1, (pageSize.height / cell).ceil());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(1 / cell);
    final paint = Paint()..color = const Color(0xFF000000);
    for (final stroke in strokes) {
      if (stroke.toolId == ToolId.highlighter) continue;
      if (FillTool.isFillStroke(stroke)) continue;
      if (stroke is CircleStroke) {
        canvas.drawCircle(
          stroke.center,
          stroke.radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.options.size,
        );
      } else if (stroke is RectangleStroke) {
        canvas.drawRect(
          stroke.rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke.options.size,
        );
      } else {
        canvas.drawPath(stroke.highQualityPath, paint);
      }
    }
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();

    final ink = Uint8List(width * height);
    for (var i = 0; i < ink.length; i++) {
      if (bytes[i * 4 + 3] > 40) ink[i] = 1;
    }
    return FillGrid(width, height, ink);
  }

  /// The area to fill around [tap] (page units), closing small gaps.
  FillRegion regionAt(Offset tap) {
    const cell = FillTool.cell;
    final tx = (tap.dx / cell).floor(), ty = (tap.dy / cell).floor();
    if (tx < 0 || ty < 0 || tx >= width || ty >= height) {
      return FillRegion.failed(FillOutcome.open);
    }
    if (ink[ty * width + tx] == 1) return FillRegion.failed(FillOutcome.onLine);

    final maxCells = (width * height * FillTool.maxShareOfPage).floor();
    for (final r in FillTool.gapSteps) {
      final blocked = r == 0 ? ink : _dilate(ink, r);
      // A gap this wide would also close over the tap: give up.
      if (blocked[ty * width + tx] == 1) break;
      final area = _flood(blocked, ty * width + tx, maxCells);
      if (area == null) continue; // escaped: try closing wider gaps
      if (r > 0) _growBack(area, r);
      return FillRegion(width, area);
    }
    return FillRegion.failed(FillOutcome.open);
  }

  /// Cells reachable from [start] without crossing [blocked], or null if
  /// the area reaches the edge of the page or grows past [maxCells].
  Uint8List? _flood(Uint8List blocked, int start, int maxCells) {
    final area = Uint8List(width * height);
    final queue = Queue<int>()..add(start);
    area[start] = 1;
    var count = 0;
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      if (++count > maxCells) return null;
      final x = i % width, y = i ~/ width;
      if (x == 0 || y == 0 || x == width - 1 || y == height - 1) return null;
      for (final n in [i - 1, i + 1, i - width, i + width]) {
        if (area[n] == 0 && blocked[n] == 0) {
          area[n] = 1;
          queue.add(n);
        }
      }
    }
    return area;
  }

  /// Widens [area] by up to [steps] cells into clear cells only, so the fill
  /// reaches the ink again after gaps were closed (and never crosses a line).
  void _growBack(Uint8List area, int steps) {
    var frontier = [
      for (var i = 0; i < area.length; i++)
        if (area[i] == 1) i,
    ];
    for (var s = 0; s < steps && frontier.isNotEmpty; s++) {
      final next = <int>[];
      for (final i in frontier) {
        final x = i % width;
        for (final n in [
          if (x > 0) i - 1,
          if (x < width - 1) i + 1,
          i - width,
          i + width,
        ]) {
          if (n < 0 || n >= area.length) continue;
          if (area[n] == 0 && ink[n] == 0) {
            area[n] = 1;
            next.add(n);
          }
        }
      }
      frontier = next;
    }
  }

  /// [src] with every ink cell widened by [r] cells in each direction.
  Uint8List _dilate(Uint8List src, int r) {
    final horizontal = Uint8List(src.length);
    for (var y = 0; y < height; y++) {
      final row = y * width;
      var last = -1 << 30; // most recent ink x at or left of here
      for (var x = 0; x < width; x++) {
        if (src[row + x] == 1) last = x;
        if (x - last <= r) horizontal[row + x] = 1;
      }
      last = 1 << 30;
      for (var x = width - 1; x >= 0; x--) {
        if (src[row + x] == 1) last = x;
        if (last - x <= r) horizontal[row + x] = 1;
      }
    }
    final out = Uint8List(src.length);
    for (var x = 0; x < width; x++) {
      var last = -1 << 30;
      for (var y = 0; y < height; y++) {
        if (horizontal[y * width + x] == 1) last = y;
        if (y - last <= r) out[y * width + x] = 1;
      }
      last = 1 << 30;
      for (var y = height - 1; y >= 0; y--) {
        if (horizontal[y * width + x] == 1) last = y;
        if (last - y <= r) out[y * width + x] = 1;
      }
    }
    return out;
  }
}

/// The cells to fill.
class FillRegion {
  new(this._width, this._cells) : outcome = FillOutcome.filled;
  new failed(this.outcome) : _width = 1, _cells = Uint8List(0);

  final FillOutcome outcome;
  final int _width;
  final Uint8List _cells;

  /// Whether [point] (page units) is inside the area.
  bool contains(Offset point) {
    final x = (point.dx / FillTool.cell).floor();
    final y = (point.dy / FillTool.cell).floor();
    final i = y * _width + x;
    return x >= 0 &&
        x < _width &&
        i >= 0 &&
        i < _cells.length &&
        _cells[i] == 1;
  }

  /// The area as rows of cells: (row, first column, last column).
  Iterable<(int, int, int)> get runs sync* {
    final height = _cells.length ~/ _width;
    for (var y = 0; y < height; y++) {
      int? start;
      for (var x = 0; x <= _width; x++) {
        final on = x < _width && _cells[y * _width + x] == 1;
        if (on && start == null) start = x;
        if (!on && start != null) {
          yield (y, start, x - 1);
          start = null;
        }
      }
    }
  }
}
