import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/data/handwriting/handwriting_recognizer.dart';
import 'package:saber/i18n/strings.g.dart';

/// Aha! copy: a small box to write a name with the pen. A moment after you
/// stop writing, the ink is read (on the tablet, offline once the language
/// pack is downloaded) and [onText] gets the text, which then stays
/// editable in the text box above. Shows nothing where recognition isn't
/// available.
class HandwritingPad extends StatefulWidget {
  const new({super.key, required this.onText, this.height = 110});

  final ValueChanged<String> onText;
  final double height;

  static final log = Logger('HandwritingPad');

  /// Whether [stroke] is a scratch-out: a scribble that goes back and forth
  /// at least three times, much longer than it is wide or tall.
  static bool isScratch(List<Offset> stroke) {
    if (stroke.length < 8) return false;
    final bounds = boundsOf(stroke);
    var length = 0.0;
    var turnsX = 0, turnsY = 0;
    double lastDx = 0, lastDy = 0;
    for (var i = 1; i < stroke.length; i++) {
      final d = stroke[i] - stroke[i - 1];
      length += d.distance;
      if (d.dx.abs() >= 2) {
        if (lastDx != 0 && d.dx.sign != lastDx.sign) turnsX++;
        lastDx = d.dx;
      }
      if (d.dy.abs() >= 2) {
        if (lastDy != 0 && d.dy.sign != lastDy.sign) turnsY++;
        lastDy = d.dy;
      }
    }
    final size = max(bounds.width, bounds.height);
    return max(turnsX, turnsY) >= 3 && size > 0 && length > size * 2.5;
  }

  static Rect boundsOf(List<Offset> stroke) {
    var rect = Rect.fromLTRB(
      stroke.first.dx,
      stroke.first.dy,
      stroke.first.dx,
      stroke.first.dy,
    );
    for (final p in stroke) {
      rect = rect.expandToInclude(Rect.fromLTRB(p.dx, p.dy, p.dx, p.dy));
    }
    return rect;
  }

  /// How long after the pen lifts the ink is read.
  static const readDelay = Duration(milliseconds: 800);

  @override
  State<HandwritingPad> createState() => _HandwritingPadState();
}

enum _PadStatus { idle, downloading, reading, failed, noText }

class _HandwritingPadState extends State<HandwritingPad> {
  final strokes = <List<Offset>>[];
  Timer? _readTimer;
  var status = _PadStatus.idle;

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    _readTimer?.cancel();
    setState(() => strokes.add([e.localPosition]));
  }

  void _move(PointerMoveEvent e) {
    if (strokes.isEmpty) return;
    setState(() => strokes.last.add(e.localPosition));
  }

  /// Also on a cancelled stroke: Android can cancel a pen stroke (e.g.
  /// near a text box), and the ink drawn so far should still be read.
  void _up(PointerEvent e) {
    if (strokes.isEmpty) return;
    _readTimer?.cancel();
    if (strokes.length > 1 && HandwritingPad.isScratch(strokes.last)) {
      // A scribble over earlier ink rubs that ink out.
      final scratch = HandwritingPad.boundsOf(strokes.last).inflate(4);
      final kept = [
        for (final s in strokes.take(strokes.length - 1))
          if (!HandwritingPad.boundsOf(s).overlaps(scratch)) s,
      ];
      if (kept.length < strokes.length - 1) {
        setState(() {
          strokes
            ..clear()
            ..addAll(kept);
          status = _PadStatus.idle;
        });
        if (strokes.isEmpty) {
          widget.onText('');
          return;
        }
      }
    }
    _readTimer = Timer(HandwritingPad.readDelay, _read);
  }

  Future<void> _read() async {
    if (strokes.isEmpty) return;
    final ink = [for (final s in strokes) List.of(s)];
    try {
      if (!await HandwritingRecognizer.isModelDownloaded()) {
        if (mounted) setState(() => status = _PadStatus.downloading);
        if (!await HandwritingRecognizer.downloadModel()) {
          if (mounted) setState(() => status = _PadStatus.failed);
          return;
        }
      }
      if (mounted) setState(() => status = _PadStatus.reading);
      final text = (await HandwritingRecognizer.recognizeInk(ink))
          .replaceAll('\n', ' ')
          .trim();
      if (!mounted) return;
      // Say so when nothing was recognised, rather than doing nothing.
      setState(
        () => status = text.isEmpty ? _PadStatus.noText : _PadStatus.idle,
      );
      if (text.isNotEmpty) widget.onText(text);
    } catch (e, st) {
      HandwritingPad.log.warning('Could not read the handwriting: $e', e, st);
      if (mounted) setState(() => status = _PadStatus.failed);
    }
  }

  void _clear() {
    _readTimer?.cancel();
    setState(() {
      strokes.clear();
      status = _PadStatus.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!HandwritingRecognizer.isSupported) return const SizedBox.shrink();
    final colorScheme = ColorScheme.of(context);
    final strings = t.editor.handwritingPad;
    final note = switch (status) {
      _PadStatus.idle => null,
      _PadStatus.downloading => strings.downloading,
      _PadStatus.reading => strings.reading,
      _PadStatus.failed => strings.failed,
      _PadStatus.noText => strings.noText,
    };

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 4,
      children: [
        SizedBox(
          height: widget.height,
          child: DecoratedBox(
            key: const ValueKey('handwritingPad'),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  if (strokes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const .symmetric(horizontal: 12),
                        child: Text(
                          strings.hint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
                      onPointerCancel: _up,
                      child: CustomPaint(
                        painter: _InkPainter(strokes, colorScheme.onSurface),
                      ),
                    ),
                  ),
                  if (strokes.isNotEmpty)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: IconButton(
                        tooltip: strings.clear,
                        onPressed: _clear,
                        icon: const Icon(Icons.backspace_outlined, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (note != null)
          Text(
            note,
            style: TextTheme.of(context).bodySmall?.copyWith(
              color: status == _PadStatus.failed || status == _PadStatus.noText
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _InkPainter extends CustomPainter {
  new(this.strokes, this.colour);

  final List<List<Offset>> strokes;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
