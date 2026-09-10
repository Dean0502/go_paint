import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('KidzCanvasController Tests', () {
    test('Records pointer lifecycle and accumulates completed stroke', () {
      final controller = KidzCanvasController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      expect(controller.strokes, isEmpty);
      expect(controller.activeStroke, isNull);
      expect(controller.isDrawing, isFalse);

      // 1. Pointer Down
      controller.handlePointerDown(const PointerSample(
        position: Offset(10, 10),
        timestamp: Duration.zero,
        pointerId: 1,
      ));

      expect(controller.isDrawing, isTrue);
      expect(controller.activeStroke, isNotNull);
      expect(notifyCount, greaterThan(0));

      // 2. Pointer Move
      controller.handlePointerMove(const PointerSample(
        position: Offset(30, 30),
        timestamp: Duration(milliseconds: 16),
        pointerId: 1,
      ));

      expect(controller.activeStroke!.points.length, greaterThanOrEqualTo(1));

      // 3. Pointer Up
      controller.handlePointerUp(const PointerSample(
        position: Offset(50, 50),
        timestamp: Duration(milliseconds: 32),
        pointerId: 1,
      ));

      expect(controller.isDrawing, isFalse);
      expect(controller.activeStroke, isNull);
      expect(controller.strokes.length, equals(1));
      expect(controller.strokes.first.isComplete, isTrue);
    });

    test('Undo and redo accurately manage history stack', () {
      final controller = KidzCanvasController();

      // Add two strokes
      for (int i = 0; i < 2; i++) {
        controller.handlePointerDown(PointerSample(
          position: Offset(i * 20.0, 0),
          timestamp: Duration.zero,
          pointerId: 1,
        ));
        controller.handlePointerMove(PointerSample(
          position: Offset(i * 20.0 + 10.0, 10),
          timestamp: const Duration(milliseconds: 10),
          pointerId: 1,
        ));
        controller.handlePointerUp(PointerSample(
          position: Offset(i * 20.0 + 20.0, 20),
          timestamp: const Duration(milliseconds: 20),
          pointerId: 1,
        ));
      }

      expect(controller.strokes.length, equals(2));
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      // Undo one stroke
      controller.undo();
      expect(controller.strokes.length, equals(1));
      expect(controller.canRedo, isTrue);

      // Redo
      controller.redo();
      expect(controller.strokes.length, equals(2));
      expect(controller.canRedo, isFalse);
    });

    test('Clear resets all strokes and history', () {
      final controller = KidzCanvasController();
      controller.handlePointerDown(const PointerSample(
          position: Offset(10, 10), timestamp: Duration.zero, pointerId: 1));
      controller.handlePointerUp(const PointerSample(
          position: Offset(20, 20),
          timestamp: Duration(milliseconds: 10),
          pointerId: 1));

      expect(controller.strokes.length, equals(1));
      controller.clear();
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });
  });
}
