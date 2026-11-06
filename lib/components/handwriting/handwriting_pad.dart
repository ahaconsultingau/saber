import 'dart:async';

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

  /// How long after the pen lifts the ink is read.
  static const readDelay = Duration(milliseconds: 800);

  @override
  State<HandwritingPad> createState() => _HandwritingPadState();
}

enum _PadStatus { idle, downloading, reading, failed }

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

  void _up(PointerUpEvent e) {
    _readTimer?.cancel();
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
      setState(() => status = _PadStatus.idle);
      if (text.isNotEmpty) widget.onText(text);
    } catch (_) {
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
                      child: Text(
                        strings.hint,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
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
              color: status == _PadStatus.failed
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
