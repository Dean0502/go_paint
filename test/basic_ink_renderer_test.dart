import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('BasicInkRenderer Tests', () {
    const renderer = BasicInkRenderer();

    test('Renders single-tap dab without exception', () {
      final stroke = Stroke(
        id: 'tap_1',
        points: const [
          StrokePoint(position: Offset(50, 50), timestamp: Duration.zero),
        ],
        color: Colors.black,
        baseWidth: 6.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => renderer.render(canvas, stroke), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Renders multi-point continuous smooth line without exception', () {
      final stroke = Stroke(
        id: 'line_1',
        points: const [
          StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          StrokePoint(position: Offset(30, 20), timestamp: Duration(milliseconds: 10)),
          StrokePoint(position: Offset(60, 50), timestamp: Duration(milliseconds: 20)),
          StrokePoint(position: Offset(100, 80), timestamp: Duration(milliseconds: 30)),
        ],
        color: Colors.black,
        baseWidth: 4.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => renderer.render(canvas, stroke), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('CanvasRenderer renders completed strokes and active stroke', () {
      const compositor = CanvasRenderer(strokeRenderer: BasicInkRenderer());
      final strokes = [
        Stroke(
          id: 'stroke_1',
          points: const [
            StrokePoint(position: Offset(0, 0), timestamp: Duration.zero),
            StrokePoint(position: Offset(50, 50), timestamp: Duration(milliseconds: 10)),
          ],
        ),
      ];
      final active = Stroke(
        id: 'active_1',
        points: const [
          StrokePoint(position: Offset(100, 100), timestamp: Duration.zero),
          StrokePoint(position: Offset(120, 120), timestamp: Duration(milliseconds: 5)),
        ],
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => compositor.render(
          canvas: canvas,
          size: const Size(500, 500),
          strokes: strokes,
          activeStroke: active,
        ),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
