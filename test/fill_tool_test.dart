import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/tools/fill.dart';
import 'package:sbn/tool_id.dart';

/// Joel: "an option that gives a paint fill, so if I do bubble text or a
/// shape I can paint fill the shape in one hit". Solid colour, one tap per
/// letter, gaps closed so the colour doesn't spill, fill behind writing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorPage page;
  setUp(() => page = EditorPage(width: 1000, height: 1400));

  Stroke pen(List<Offset> points) => Stroke(
    color: Colors.black,
    pressureEnabled: false,
    options: StrokeOptions(size: 4, isComplete: true),
    pageIndex: 0,
    page: page,
    toolId: ToolId.fountainPen,
  )..addPoints(points);

  /// A hand-drawn circle, leaving out [gapDegrees] at the right.
  Stroke circle(Offset c, double r, {double gapDegrees = 0}) => pen([
    for (var a = gapDegrees / 2; a <= 360 - gapDegrees / 2; a += 4)
      c + Offset(r * cos(a * pi / 180), r * sin(a * pi / 180)),
  ]);

  Future<FillResult> tapAt(Offset p) =>
      FillTool.fill(page: page, pageIndex: 0, tap: p, color: Colors.orange);

  double filledArea(FillResult r) => r.strokes.fold(0.0, (sum, s) {
    final p = s.inputPoints;
    return sum + (p.last.dx - p.first.dx + FillTool.rowWidth) * FillTool.cell;
  });

  test(
    'A tap inside a circle fills it, in solid colour, under the ink',
    () async {
      page.strokes.add(circle(const Offset(500, 500), 100));
      final result = await tapAt(const Offset(500, 500));
      expect(result.outcome, FillOutcome.filled);
      expect(result.strokes, isNotEmpty);
      // Close to the circle's area (pi * 100^2), inside the line.
      expect(
        filledArea(result),
        closeTo(pi * 100 * 100, pi * 100 * 100 * 0.08),
      );
      for (final s in result.strokes) {
        expect(s.color, Colors.orange.withAlpha(255));
        expect(s.toolId, ToolId.shapePen, reason: 'drawn before the pens');
        expect(FillTool.isFillStroke(s), isTrue);
        final p = s.inputPoints;
        expect(p.first.dx, greaterThan(395));
        expect(p.last.dx, lessThan(605));
      }
      // Shape-pen strokes sort before the pens, so the fill sits under ink.
      expect(
        EditorPage.compareStrokes(result.strokes.first, page.strokes.first),
        lessThan(0),
      );
    },
  );

  test('The hole in a letter stays clear', () async {
    page.strokes
      ..add(circle(const Offset(500, 500), 120))
      ..add(circle(const Offset(500, 500), 40)); // the hole, like an O
    final result = await tapAt(const Offset(500, 410));
    expect(result.outcome, FillOutcome.filled);
    const ring = pi * (120 * 120 - 40 * 40);
    expect(filledArea(result), closeTo(ring, ring * 0.1));
    final region = result.strokes.where((s) {
      final p = s.inputPoints;
      return (p.first.dy - 500).abs() < 2;
    });
    for (final s in region) {
      final p = s.inputPoints;
      expect(
        p.first.dx > 540 || p.last.dx < 460,
        isTrue,
        reason: 'nothing inside the hole',
      );
    }
  });

  test(
    'Writing inside the shape stays on top: the fill goes round it',
    () async {
      page.strokes
        ..add(circle(const Offset(500, 500), 150))
        ..add(pen([const Offset(450, 500), const Offset(550, 500)])); // a word
      final result = await tapAt(const Offset(500, 420));
      expect(result.outcome, FillOutcome.filled);
      for (final s in result.strokes) {
        final p = s.inputPoints;
        // No row runs across the writing at y = 500.
        if ((p.first.dy - 500).abs() < 1) {
          expect(p.last.dx < 450 || p.first.dx > 550, isTrue);
        }
      }
    },
  );

  test('A small gap (about 3 mm) is closed and nothing spills', () async {
    // A gap of 6 degrees on r=150 is about 16 units, ~3 mm on A4.
    page.strokes.add(circle(const Offset(500, 500), 150, gapDegrees: 6));
    final result = await tapAt(const Offset(500, 500));
    expect(result.outcome, FillOutcome.filled);
    for (final s in result.strokes) {
      expect(s.inputPoints.last.dx, lessThan(660), reason: 'no spill outside');
    }
  });

  test('A big gap fills nothing and says the shape is open', () async {
    page.strokes.add(circle(const Offset(500, 500), 150, gapDegrees: 40));
    final result = await tapAt(const Offset(500, 500));
    expect(result.outcome, FillOutcome.open);
    expect(result.strokes, isEmpty);
  });

  test('A tap outside any shape fills nothing', () async {
    page.strokes.add(circle(const Offset(500, 500), 100));
    final result = await tapAt(const Offset(100, 1300));
    expect(result.outcome, FillOutcome.open);
  });

  test('Filling again with another colour replaces the first fill', () async {
    page.strokes.add(circle(const Offset(500, 500), 100));
    final first = await tapAt(const Offset(500, 500));
    page.strokes.insertAll(0, first.strokes);
    final second = await FillTool.fill(
      page: page,
      pageIndex: 0,
      tap: const Offset(500, 500),
      color: Colors.green,
    );
    expect(second.outcome, FillOutcome.filled);
    expect(second.replaced.toSet(), first.strokes.toSet());
  });
}
