import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/table_lines.dart';

void main() {
  group('TableLines.build', () {
    test('a 2 × 3 table has 3 horizontal and 4 vertical lines', () {
      const rect = Rect.fromLTWH(100, 200, 300, 120);
      final lines = TableLines.build(rect, 2, 3);
      expect(lines, hasLength(3 + 4));

      final horizontal = lines.take(3).toList();
      expect(horizontal.map((l) => l.$1.dy), [200, 260, 320]);
      for (final (start, end) in horizontal) {
        expect(start.dx, 100);
        expect(end.dx, 400);
        expect(start.dy, end.dy);
      }

      final vertical = lines.skip(3).toList();
      expect(vertical.map((l) => l.$1.dx), [100, 200, 300, 400]);
      for (final (start, end) in vertical) {
        expect(start.dy, 200);
        expect(end.dy, 320);
        expect(start.dx, end.dx);
      }
    });
  });

  group('TableLines.placement', () {
    const page = Size(1000, 1400);

    test('is centred and 80% of the page wide', () {
      final rect = TableLines.placement(page, 3);
      expect(rect.width, 800);
      expect(rect.center, page.center(Offset.zero));
      expect(rect.height, 180); // 3 rows × 60
    });

    test('never taller than 80% of the page', () {
      final rect = TableLines.placement(page, TableLines.maxRows);
      expect(rect.height, lessThanOrEqualTo(page.height * 0.8));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(page.height));
    });
  });
}
