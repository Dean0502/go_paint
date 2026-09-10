import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('KidzCanvas Widget Tests', () {
    testWidgets('Renders KidzCanvas and draws on pointer drag gesture',
        (tester) async {
      final controller = KidzCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: KidzCanvas(controller: controller),
            ),
          ),
        ),
      );

      expect(find.byType(KidzCanvas), findsOneWidget);
      expect(controller.strokes, isEmpty);

      // Perform touch drag across canvas
      final gesture = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(controller.isDrawing, isTrue);

      await gesture.moveTo(const Offset(100, 100));
      await tester.pump();

      await gesture.moveTo(const Offset(150, 80));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(controller.isDrawing, isFalse);
      expect(controller.strokes.length, equals(1));
      expect(controller.strokes.first.points.length, greaterThanOrEqualTo(2));
    });
  });
}
