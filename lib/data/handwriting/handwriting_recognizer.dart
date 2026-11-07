import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/handwriting/ink_lines.dart';
import 'package:sbn/tool_id.dart';

/// Turns handwriting into text on the device, using Google's ML Kit
/// digital ink recognition.
///
/// Recognition runs offline. The language pack is downloaded once (it needs
/// an internet connection that first time) and kept on the device.
abstract final class HandwritingRecognizer {
  /// ML Kit's English (Australia) model.
  static const languageTag = 'en-AU';

  /// ML Kit only runs on Android and iOS.
  static bool get isSupported =>
      debugIsSupported ?? (Platform.isAndroid || Platform.isIOS);

  /// Test stand-ins: tests run on Linux, where ML Kit isn't available.
  @visibleForTesting
  static bool? debugIsSupported;
  @visibleForTesting
  static Future<String> Function(List<Stroke> strokes)? debugRecognize;

  static final _modelManager = mlkit.DigitalInkRecognizerModelManager();

  @visibleForTesting
  static Future<String> Function(List<List<Offset>> strokes)? debugRecognizeInk;

  static Future<bool> isModelDownloaded() async =>
      debugRecognize != null ||
      debugRecognizeInk != null ||
      await _modelManager.isModelDownloaded(languageTag);

  /// Downloads the language pack. Works on mobile data as well as Wi-Fi.
  static Future<bool> downloadModel() =>
      _modelManager.downloadModel(languageTag, isWifiRequired: false);

  /// Whether [stroke] is handwriting worth recognising: not a highlighter
  /// mark and not a snapped shape.
  static bool isHandwriting(Stroke stroke) =>
      stroke.toolId != ToolId.highlighter &&
      stroke is! CircleStroke &&
      stroke is! RectangleStroke &&
      stroke.inputPoints.isNotEmpty;

  /// Recognises [strokes] one line at a time and returns the text,
  /// lines separated by newlines.
  static Future<String> recognize(List<Stroke> strokes) async {
    final handwriting = strokes.where(isHandwriting).toList();
    if (debugRecognize case final debugRecognize?) {
      return debugRecognize(handwriting);
    }
    return _recognizeLines(
      InkLines.build([for (final stroke in handwriting) stroke.inputPoints]),
    );
  }

  /// Aha! copy: recognises ink drawn outside a note (e.g. a name written in
  /// a pen box): each stroke a list of points, in drawing order.
  static Future<String> recognizeInk(List<List<Offset>> strokes) async {
    if (debugRecognizeInk case final debugRecognizeInk?) {
      return debugRecognizeInk(strokes);
    }
    return _recognizeLines(InkLines.build(strokes));
  }

  /// One recognizer, kept for the life of the app. The Android side of the
  /// ML Kit plugin never answers "close", so closing (and waiting for it)
  /// after each read left every read stuck on "Reading…".
  static mlkit.DigitalInkRecognizer? _recognizer;

  /// How long one line may take before it counts as failed.
  static const _lineTimeout = Duration(seconds: 20);

  static Future<String> _recognizeLines(
    List<List<List<InkPoint>>> lines,
  ) async {
    final recognizer = _recognizer ??= mlkit.DigitalInkRecognizer(
      languageCode: languageTag,
    );
    final text = <String>[];
    for (final line in lines) {
      final ink = mlkit.Ink()
        ..strokes = [
          for (final stroke in line)
            mlkit.Stroke()
              ..points = [
                for (final p in stroke)
                  mlkit.StrokePoint(x: p.x, y: p.y, t: p.t),
              ],
        ];
      final candidates = await recognizer
          .recognize(
            ink,
            context: mlkit.DigitalInkRecognitionContext(
              // The end of the previous line helps with words split
              // across lines and with capitalisation.
              preContext: text.isEmpty ? null : _tail(text.last),
            ),
          )
          .timeout(_lineTimeout);
      if (candidates.isNotEmpty) text.add(candidates.first.text);
    }
    return text.join('\n');
  }

  static String _tail(String s) =>
      s.length <= 20 ? s : s.substring(s.length - 20);
}
