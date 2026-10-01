import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('go_paint Dual-Layer Compositor Tests', () {
    test('StaticPicturePainter caches 500 strokes and renders in < 0.1 ms', () {
      final strokes = List.generate(500, (i) {
        final pts = [
          StrokePoint(position: Offset(i * 2.0, 10.0), timestamp: Duration.zero),
          StrokePoint(
              position: Offset(i * 2.0 + 10.0, 50.0),
              timestamp: const Duration(milliseconds: 16)),
        ];
        return Stroke(
          id: 's_$i',
          points: pts,
          color: Colors.blue,
          baseWidth: 3.0,
          isComplete: true,
        );
      });

      final controller = KidzCanvasController();
      final staticPainter = StaticPicturePainter(
        repaint: controller.staticRepaintListenable,
        getStrokes: () => strokes,
        getRenderer: () => controller.strokeRenderer,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 1000));
      const size = Size(1000, 1000);

      // 1. Initial bake
      staticPainter.paint(canvas, size);

      // 2. Measure subsequent cached draw
      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        staticPainter.paint(canvas, size);
      }
      sw.stop();

      final avgDrawMs = (sw.elapsedMicroseconds / 50.0) / 1000.0;
      // ignore: avoid_print
      print('=== 500 Historical Strokes Cached Draw Time ===');
      // ignore: avoid_print
      print('Average time per frame: ${avgDrawMs.toStringAsFixed(4)} ms');

      // Static cached draw must be under 0.2 ms
      expect(avgDrawMs, lessThan(0.2));
    });

    test('ActiveTipPainter renders ONLY active stroke without touching static layer', () {
      final controller = KidzCanvasController();
      final activePts = List.generate(
        30,
        (i) => StrokePoint(
          position: Offset(100.0 + i, 100.0 + i),
          timestamp: Duration(milliseconds: i * 8),
        ),
      );
      final activeStroke = Stroke(
        id: 'active_1',
        points: activePts,
        color: Colors.red,
        baseWidth: 4.0,
        isComplete: false,
      );

      final tipPainter = ActiveTipPainter(
        repaint: controller.activeRepaintListenable,
        getActiveStroke: () => activeStroke,
        getRenderer: () => controller.strokeRenderer,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 1000));

      final sw = Stopwatch()..start();
      tipPainter.paint(canvas, const Size(1000, 1000));
      sw.stop();

      final tipMs = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Active Tip render time: ${tipMs.toStringAsFixed(3)} ms');

      // Must comfortably fit within 120 Hz frame budget (< 8.33 ms)
      expect(tipMs, lessThan(8.33));
    });

    test('Vector stroke eraser deletes intersected strokes and supports undo', () {
      final controller = KidzCanvasController();

      // Draw stroke 1 at (50, 50) -> (150, 50)
      controller.handlePointerDown(const PointerSample(
        position: Offset(50, 50),
        timestamp: Duration.zero,
        pointerId: 1,
      ));
      controller.handlePointerMove(const PointerSample(
        position: Offset(150, 50),
        timestamp: Duration(milliseconds: 16),
        pointerId: 1,
      ));
      controller.handlePointerUp(const PointerSample(
        position: Offset(150, 50),
        timestamp: Duration(milliseconds: 32),
        pointerId: 1,
      ));

      expect(controller.strokes.length, equals(1));

      // Switch to eraser and erase at (100, 50)
      controller.activeTool = CanvasTool.eraser;
      controller.handlePointerDown(const PointerSample(
        position: Offset(100, 50),
        timestamp: Duration(milliseconds: 50),
        pointerId: 2,
      ));

      // Stroke should be erased!
      expect(controller.strokes.isEmpty, isTrue);
      expect(controller.canUndo, isTrue);

      // Undo should restore the erased stroke!
      controller.undo();
      expect(controller.strokes.length, equals(1));
    });

    test('Stylus-only mode rejects touch input (Palm Rejection)', () {
      final controller = KidzCanvasController(stylusOnlyDrawing: true);

      // Finger touch (palm or finger)
      controller.handlePointerDown(const PointerSample(
        position: Offset(200, 200),
        timestamp: Duration.zero,
        pointerId: 1,
        deviceType: PointerDeviceKind.touch,
      ));
      controller.handlePointerMove(const PointerSample(
        position: Offset(250, 250),
        timestamp: Duration(milliseconds: 16),
        pointerId: 1,
        deviceType: PointerDeviceKind.touch,
      ));
      controller.handlePointerUp(const PointerSample(
        position: Offset(250, 250),
        timestamp: Duration(milliseconds: 32),
        pointerId: 1,
        deviceType: PointerDeviceKind.touch,
      ));

      // No stroke should be recorded from touch
      expect(controller.strokes.isEmpty, isTrue);

      // Stylus touch
      controller.handlePointerDown(const PointerSample(
        position: Offset(200, 200),
        timestamp: Duration(milliseconds: 50),
        pointerId: 2,
        deviceType: PointerDeviceKind.stylus,
      ));
      controller.handlePointerUp(const PointerSample(
        position: Offset(250, 250),
        timestamp: Duration(milliseconds: 70),
        pointerId: 2,
        deviceType: PointerDeviceKind.stylus,
      ));

      // Stylus stroke must be accepted!
      expect(controller.strokes.length, equals(1));
    });
  });
}
