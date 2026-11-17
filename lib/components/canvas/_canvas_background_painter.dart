import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:sbn/canvas_background_pattern.dart';

class CanvasBackgroundPainter extends CustomPainter {
  const new({
    required this.invert,
    required this.backgroundColor,
    this.backgroundPattern = .none,
    required this.lineHeight,
    required this.lineThickness,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.red,
    this.preview = false,
  });

  final bool invert;
  final Color backgroundColor;

  /// The pattern to use for the background. See [CanvasBackgroundPatterns].
  final CanvasBackgroundPattern backgroundPattern;

  /// The height between each line in the background pattern
  final int lineHeight;
  final int lineThickness;
  final Color primaryColor, secondaryColor;

  /// Whether to draw the background pattern in a preview mode (more opaque).
  final bool preview;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & size;
    final paint = Paint();

    paint.color = backgroundColor.withInversion(invert);
    canvas.drawRect(canvasRect, paint);

    paint.strokeWidth = lineThickness.toDouble();

    if (backgroundPattern.requiresClipping) {
      canvas.save();
      canvas.clipRect(canvasRect);
    }

    for (final element in getPatternElements(
      pattern: backgroundPattern,
      size: size,
      lineHeight: lineHeight,
    )) {
      if (element.secondaryColor) {
        paint.color = secondaryColor.withValues(alpha: preview ? 0.5 : 0.2);
      } else {
        paint.color = primaryColor.withValues(alpha: preview ? 0.5 : 0.2);
      }

      if (element.isLine) {
        canvas.drawLine(element.start, element.end, paint);
      } else {
        canvas.drawCircle(element.start, paint.strokeWidth * 4 / 3, paint);
      }
    }

    if (backgroundPattern.requiresClipping) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CanvasBackgroundPainter oldDelegate) =>
      kDebugMode ||
      oldDelegate.invert != invert ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.backgroundPattern != backgroundPattern ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;

  static Iterable<PatternElement> getPatternElements({
    required CanvasBackgroundPattern pattern,
    required Size size,
    required int lineHeight,
  }) sync* {
    switch (pattern) {
      case .none:
        return;
      case .collegeLtr:
      case .collegeRtl:
      case .lined:
        // horizontal lines
        for (double y = lineHeight * 2; y < size.height; y += lineHeight) {
          yield PatternElement(
            Offset(0, y),
            Offset(size.width, y),
            isLine: true,
          );
        }

        // vertical line
        if (pattern == .collegeLtr) {
          yield PatternElement(
            Offset(lineHeight * 2, 0),
            Offset(lineHeight * 2, size.height),
            isLine: true,
            secondaryColor: true,
          );
        } else if (pattern == .collegeRtl) {
          yield PatternElement(
            Offset(size.width - lineHeight * 2, 0),
            Offset(size.width - lineHeight * 2, size.height),
            isLine: true,
            secondaryColor: true,
          );
        }
      case .grid:
        for (double y = lineHeight * 2; y < size.height; y += lineHeight) {
          yield PatternElement(
            Offset(0, y),
            Offset(size.width, y),
            isLine: true,
          );
        }
        for (double x = 0; x < size.width; x += lineHeight) {
          yield PatternElement(
            Offset(x, lineHeight * 2),
            Offset(x, size.height),
            isLine: true,
          );
        }
      case .dots:
        for (double y = lineHeight * 2; y <= size.height; y += lineHeight) {
          for (double x = 0; x <= size.width; x += lineHeight) {
            yield PatternElement(Offset(x, y), Offset(x, y), isLine: false);
          }
        }
      case .isometric:
        // Aha! copy: lines at 30° up, 30° down and upright, making
        // triangles with sides [lineHeight] long, below the usual top margin.
        final side = lineHeight.toDouble();
        final top = lineHeight * 2.0;
        final slope = math.tan(math.pi / 6);
        final step = side / math.cos(math.pi / 6);
        // The part of the line y = y0 + s·x inside the page, below [top].
        PatternElement? clip(double y0, double s) {
          var x0 = 0.0, x1 = size.width;
          final a = (top - y0) / s, b = (size.height - y0) / s;
          x0 = math.max(x0, math.min(a, b));
          x1 = math.min(x1, math.max(a, b));
          if (x1 - x0 < 0.5) return null;
          return PatternElement(
            Offset(x0, (y0 + s * x0).clamp(top, size.height)),
            Offset(x1, (y0 + s * x1).clamp(top, size.height)),
            isLine: true,
          );
        }

        final rise = size.width * slope;
        for (double c = top - rise; c < size.height; c += step) {
          if (clip(c, slope) case final line?) yield line;
        }
        for (double c = top; c < size.height + rise; c += step) {
          if (clip(c, -slope) case final line?) yield line;
        }
        for (double x = 0; x <= size.width; x += side * math.cos(math.pi / 6)) {
          yield PatternElement(
            Offset(x, top),
            Offset(x, size.height),
            isLine: true,
          );
        }
      case .staffs:
      case .tablature:
        final staffSpaces = pattern == .staffs ? 4 : 5;
        final staffHeight = lineHeight * staffSpaces;
        final staffSpacing = lineHeight * 3;

        for (
          double topOfStaff = staffSpacing.toDouble() - lineHeight;
          topOfStaff + staffHeight < size.height;
          topOfStaff += staffHeight + staffSpacing
        ) {
          // horizontal lines
          for (int line = 0; line < staffSpaces + 1; line++) {
            yield PatternElement(
              Offset(lineHeight.toDouble(), topOfStaff + lineHeight * line),
              Offset(size.width - lineHeight, topOfStaff + lineHeight * line),
              isLine: true,
            );
          }

          // vertical lines on either side
          yield PatternElement(
            Offset(lineHeight.toDouble(), topOfStaff),
            Offset(lineHeight.toDouble(), topOfStaff + staffHeight),
            isLine: true,
          );
          yield PatternElement(
            Offset(size.width - lineHeight, topOfStaff),
            Offset(size.width - lineHeight, topOfStaff + staffHeight),
            isLine: true,
          );
        }
      case .cornell:
        // half-width line for name field
        yield PatternElement(
          Offset(lineHeight.toDouble(), lineHeight * 2),
          Offset(size.width / 2 - lineHeight / 2, lineHeight * 2),
          isLine: true,
        );
        // half-width line for date field
        yield PatternElement(
          Offset(size.width / 2 + lineHeight / 2, lineHeight * 2),
          Offset(size.width - lineHeight, lineHeight * 2),
          isLine: true,
        );
        // full-width line for title field
        yield PatternElement(
          Offset(lineHeight.toDouble(), lineHeight * 3),
          Offset(size.width - lineHeight, lineHeight * 3),
          isLine: true,
        );

        // lines for main notes
        final left = size.width * 0.35; // 35% width reserved for cues column
        final bottom = size.height * 0.7; // 30% height reserved for summary
        for (double y = lineHeight * 5; y < bottom; y += lineHeight) {
          yield PatternElement(
            Offset(left, y),
            Offset(size.width - lineHeight, y),
            isLine: true,
          );
        }
    }
  }
}

class PatternElement {
  final Offset start, end;

  /// Whether this is a line or a dot
  final bool isLine;

  /// Whether this should use a secondary color
  final bool secondaryColor;

  const new(
    this.start,
    this.end, {
    this.isLine = true,
    this.secondaryColor = false,
  });
}
