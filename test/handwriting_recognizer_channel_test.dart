import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/handwriting/handwriting_recognizer.dart';

/// Reported on the tablet: writing a name stayed on "Reading your
/// handwriting…" for ever. The Android side of the ML Kit plugin never
/// answers "close", so waiting for it hung after the text was read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_digital_ink_recognizer');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    HandwritingRecognizer.debugRecognizeInk = null;
    HandwritingRecognizer.debugRecognize = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call.method);
          switch (call.method) {
            case 'vision#startDigitalInkRecognizer':
              return Future.value([
                {'text': 'Bayside Council', 'score': 1.0},
              ]);
            case 'vision#closeDigitalInkRecognizer':
              // Like the real Android plugin: never answers.
              return Completer<Object?>().future;
          }
          return Future.value(true);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final ink = [
    [for (var i = 0; i < 10; i++) Offset(i * 5.0, 10 + (i % 3) * 4.0)],
  ];

  test('Reading ink finishes even though "close" never answers', () async {
    final text = await HandwritingRecognizer.recognizeInk(ink)
        .timeout(const Duration(seconds: 5));
    expect(text, 'Bayside Council');
  });

  test('It reads again the second time too', () async {
    await HandwritingRecognizer.recognizeInk(ink)
        .timeout(const Duration(seconds: 5));
    final again = await HandwritingRecognizer.recognizeInk(ink)
        .timeout(const Duration(seconds: 5));
    expect(again, 'Bayside Council');
  });
}
