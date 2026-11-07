import 'dart:math';
import 'dart:ui';

/// A single point of ink, with a synthetic timestamp in milliseconds.
typedef InkPoint = ({double x, double y, int t});

/// Groups handwritten strokes into lines of text and orders them for
/// handwriting recognition.
///
/// Recognisers work best one line at a time, in the order the ink was
/// written. Saber stores strokes in the order they were drawn, so the order
/// within a line is kept, and lines are ordered top to bottom.
abstract final class InkLines {
  /// How far (as a fraction of a line's height) a small stroke's centre may
  /// sit above or below a line and still belong to it, e.g. the dot on an i
  /// or the cross on a t.
  static const _lineTolerance = 0.35;

  /// Milliseconds between consecutive points, and the pause between strokes.
  /// Saber doesn't record timestamps, so plausible ones are made up.
  static const _msPerPoint = 10;
  static const _msBetweenStrokes = 100;

  /// Groups [strokes] (each a list of points, in drawing order) into lines.
  ///
  /// Returns the stroke indices for each line, lines top to bottom and
  /// strokes in drawing order. Empty strokes are left out.
  static List<List<int>> group(List<List<Offset>> strokes) {
    final bounds = <int, Rect>{
      for (var i = 0; i < strokes.length; i++)
        if (strokes[i].isNotEmpty) i: _bounds(strokes[i]),
    };

    // Tall strokes set out the lines first, so small marks (dots, commas)
    // then join the line they sit nearest to.
    final bySize = bounds.keys.toList()
      ..sort((a, b) => bounds[b]!.height.compareTo(bounds[a]!.height));

    final lineBands = <Rect>[];
    final lineMembers = <List<int>>[];
    for (final i in bySize) {
      final rect = bounds[i]!;
      final line = _bestLine(rect, lineBands);
      if (line == null) {
        lineBands.add(rect);
        lineMembers.add([i]);
      } else {
        lineBands[line] = lineBands[line].expandToInclude(
          // Only let full-height strokes grow the band, so a stray mark
          // doesn't merge two lines.
          rect.height >= lineBands[line].height * 0.5
              ? rect
              : Rect.fromLTRB(
                  rect.left,
                  lineBands[line].top,
                  rect.right,
                  lineBands[line].bottom,
                ),
        );
        lineMembers[line].add(i);
      }
    }

    final order = List.generate(
      lineBands.length,
      (i) => i,
    )..sort((a, b) => lineBands[a].center.dy.compareTo(lineBands[b].center.dy));
    return [for (final line in order) lineMembers[line]..sort()];
  }

  /// Which existing line [rect] belongs to, or null for a new line.
  static int? _bestLine(Rect rect, List<Rect> lineBands) {
    int? best;
    var bestScore = 0.0;
    for (var line = 0; line < lineBands.length; line++) {
      final band = lineBands[line];
      final overlap = min(rect.bottom, band.bottom) - max(rect.top, band.top);
      final smaller = max(1.0, min(rect.height, band.height));
      final overlapRatio = overlap / smaller;

      final tolerance = band.height * _lineTolerance;
      final centreInside =
          rect.center.dy >= band.top - tolerance &&
          rect.center.dy <= band.bottom + tolerance;

      final score = overlapRatio >= 0.5
          ? overlapRatio
          : centreInside && rect.height < band.height * 0.5
          ? 0.25
          : 0.0;
      if (score > bestScore) {
        bestScore = score;
        best = line;
      }
    }
    return best;
  }

  /// Builds recognition-ready ink for each line: a list of strokes,
  /// each a list of timestamped points.
  static List<List<List<InkPoint>>> build(List<List<Offset>> strokes) {
    var t = 0;
    final lines = <List<List<InkPoint>>>[];
    for (final line in group(strokes)) {
      final inkStrokes = <List<InkPoint>>[];
      for (final i in line) {
        inkStrokes.add([
          for (final p in strokes[i]) (x: p.dx, y: p.dy, t: t += _msPerPoint),
        ]);
        t += _msBetweenStrokes;
      }
      lines.add(inkStrokes);
    }
    return lines;
  }

  static Rect _bounds(List<Offset> points) {
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final p in points) {
      left = min(left, p.dx);
      right = max(right, p.dx);
      top = min(top, p.dy);
      bottom = max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
