import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/handwriting/ink_lines.dart';

/// A stroke from (x, top) to (x + 20, top + height), as a few points.
List<Offset> stroke(double x, double top, double height) => [
  Offset(x, top),
  Offset(x + 10, top + height / 2),
  Offset(x + 20, top + height),
];

void main() {
  group('InkLines.group', () {
    test('splits two lines and orders them top to bottom', () {
      final strokes = [
        stroke(0, 200, 40), // line 2, written first
        stroke(30, 200, 40), // line 2
        stroke(0, 100, 40), // line 1
        stroke(30, 105, 35), // line 1
      ];
      expect(InkLines.group(strokes), [
        [2, 3],
        [0, 1],
      ]);
    });

    test('keeps drawing order within a line', () {
      final strokes = [
        stroke(60, 100, 40),
        stroke(0, 100, 40),
        stroke(30, 100, 40),
      ];
      expect(InkLines.group(strokes), [
        [0, 1, 2],
      ]);
    });

    test('puts the dot of an i on its own line, not a new one', () {
      final strokes = [
        stroke(0, 100, 40), // letter
        [const Offset(25, 90), const Offset(26, 91)], // dot just above
        stroke(0, 200, 40), // next line
      ];
      expect(InkLines.group(strokes), [
        [0, 1],
        [2],
      ]);
    });

    test('a stray small mark between lines does not merge them', () {
      final strokes = [
        stroke(0, 100, 40),
        [const Offset(50, 150), const Offset(52, 152)], // comma-sized mark
        stroke(0, 170, 40),
      ];
      final lines = InkLines.group(strokes);
      expect(lines, hasLength(2));
      expect(lines.expand((l) => l).toList()..sort(), [0, 1, 2]);
    });

    test('skips empty strokes', () {
      final strokes = [<Offset>[], stroke(0, 100, 40)];
      expect(InkLines.group(strokes), [
        [1],
      ]);
    });
  });

  group('InkLines.build', () {
    test('timestamps always increase, with a gap between strokes', () {
      final lines = InkLines.build([
        stroke(0, 100, 40),
        stroke(30, 100, 40),
        stroke(0, 200, 40),
      ]);
      expect(lines, hasLength(2));
      final times = [
        for (final line in lines)
          for (final s in line)
            for (final p in s) p.t,
      ];
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]));
      }
      final firstStrokeEnd = lines[0][0].last.t;
      final secondStrokeStart = lines[0][1].first.t;
      expect(secondStrokeStart - firstStrokeEnd, greaterThan(10));
    });

    test('keeps the coordinates', () {
      final lines = InkLines.build([
        [const Offset(1, 2), const Offset(3, 4)],
      ]);
      expect(lines.single.single.map((p) => (p.x, p.y)), [
        (1.0, 2.0),
        (3.0, 4.0),
      ]);
    });
  });
}
