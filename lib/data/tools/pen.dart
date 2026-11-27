import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

class Pen extends Tool {
  @protected
  @visibleForTesting
  new({
    required this.name,
    required this.sizeMin,
    required this.sizeMax,
    required this.sizeStep,
    required this.icon,
    required this.options,
    required this.pressureEnabled,
    required this.color,
    required this.toolId,
  });

  new fountainPen()
    : name = t.editor.pens.fountainPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = fountainPenIcon,
      options = stows.lastFountainPenOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen;

  new ballpointPen()
    : name = t.editor.pens.ballpointPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = ballpointPenIcon,
      options = stows.lastBallpointPenOptions.value,
      pressureEnabled = false,
      color = Color(stows.lastBallpointPenColor.value),
      toolId = .ballpointPen;

  /// Aha! copy: a paintbrush: thick when pressed, thin when light, with
  /// tapered ends. Saved as a fountain-pen stroke with brush settings, so
  /// the standard Saber apps (and the Mac) draw it the same.
  new brush()
    : name = t.editor.pens.brush,
      sizeMin = 2,
      sizeMax = 60,
      sizeStep = 1,
      icon = brushIcon,
      options = stows.lastBrushOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen {
    feather = stows.lastBrushFeather.value;
  }

  /// Whether this is the paintbrush (it shares the fountain pen's type).
  bool get isBrush => icon == brushIcon;

  final String name;
  final double sizeMin, sizeMax, sizeStep;
  late final int sizeStepsBetweenMinAndMax = ((sizeMax - sizeMin) / sizeStep)
      .round();
  final Object icon;

  @override
  final ToolId toolId;

  static const fountainPenIcon = FontAwesomeIcons.penFancy;
  static const ballpointPenIcon = FontAwesomeIcons.pen;
  static const brushIcon = FontAwesomeIcons.paintbrush;

  static Stroke? currentStroke;
  Color color;
  bool pressureEnabled;
  StrokeOptions options;

  /// Aha! copy: soft edges, 0 to 1 (the brush only).
  double feather = 0;

  /// Aha! copy: true while a drawing is open, so the drawing-only options
  /// (opacity) apply. Notes always draw fully opaque.
  static var drawingMode = false;

  /// Aha! copy: how see-through the paint is on drawings, 0.05 to 1.
  static double get drawingOpacity => stows.drawingOpacity.value;
  static set drawingOpacity(double value) =>
      stows.drawingOpacity.value = value.clamp(0.05, 1);

  static var _currentPen = stows.lastPenIsBrush.value
      ? Pen.brush()
      : Pen.fountainPen();
  static Pen get currentPen => _currentPen;
  static set currentPen(Pen currentPen) {
    assert(
      currentPen is! Highlighter,
      'Use Highlighter.currentHighlighter instead',
    );
    assert(currentPen is! Pencil, 'Use Pencil.currentPencil instead');
    _currentPen = currentPen;
  }

  void onDragStart(
    Offset position,
    EditorPage page,
    int pageIndex,
    double? pressure,
  ) {
    currentStroke = Stroke(
      color: drawingMode && drawingOpacity < 1 && this is! Highlighter
          ? color.withValues(alpha: color.a * drawingOpacity)
          : color,
      pressureEnabled: pressureEnabled,
      options: options.copyWith(isComplete: false),
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
      feather: feather,
    );
    onDragUpdate(position, pressure);
  }

  void onDragUpdate(Offset position, double? pressure) {
    currentStroke?.addPoint(position, pressure);
  }

  Stroke? onDragEnd() {
    final stroke = currentStroke;
    currentStroke = null;
    if (stroke == null) return null;

    return stroke
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
  }

  /// The default stroke options.
  ///
  /// Note that these are different to the default options in [StrokeOptions]
  /// e.g. [StrokeOptions.defaultSize] for historical reasons
  /// (i.e. [StrokeOptions.toJson] does not include default values.)
  static final defaultOptions = StrokeOptions(size: 5);

  static StrokeOptions get fountainPenOptions => defaultOptions.copyWith();
  static StrokeOptions get ballpointPenOptions => defaultOptions.copyWith();
  static StrokeOptions get shapePenOptions =>
      defaultOptions.copyWith(smoothing: 0, streamline: 0);
  static StrokeOptions get brushOptions => StrokeOptions(
    size: 14,
    thinning: 0.75,
    smoothing: 0.65,
    streamline: 0.5,
    start: StrokeEndOptions.start(taperEnabled: true),
    end: StrokeEndOptions.end(taperEnabled: true),
  );
  static StrokeOptions get highlighterOptions =>
      defaultOptions.copyWith(size: 50);
  static StrokeOptions get pencilOptions => defaultOptions.copyWith(
    streamline: 0.1,
    start: StrokeEndOptions.start(taperEnabled: true, customTaper: 1),
    end: StrokeEndOptions.end(taperEnabled: true, customTaper: 1),
  );
}
