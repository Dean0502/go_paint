import 'package:flutter/material.dart';
import '../stroke/stroke.dart';
import 'stroke_renderer.dart';

/// Full-surface canvas compositor that delegates stroke drawing to a [StrokeRenderer].
class CanvasRenderer {
  final StrokeRenderer strokeRenderer;

  const CanvasRenderer({
    this.strokeRenderer = const BasicInkRenderer(),
  });

  /// Renders a list of completed [strokes] and an optional in-flight [activeStroke].
  void render({
    required Canvas canvas,
    required Size size,
    required List<Stroke> strokes,
    Stroke? activeStroke,
  }) {
    for (final stroke in strokes) {
      strokeRenderer.render(canvas, stroke);
    }
    if (activeStroke != null) {
      strokeRenderer.render(canvas, activeStroke);
    }
  }
}

/// A high-performance [CustomPainter] that repaints directly via [Listenable].
///
/// By passing the canvas controller to [super(repaint: ...)], Flutter skips
/// widget reconciliation and layout, invoking [paint] directly on the render tree.
class CanvasCustomPainter extends CustomPainter {
  final List<Stroke> Function() getStrokes;
  final Stroke? Function() getActiveStroke;
  final CanvasRenderer renderer;

  CanvasCustomPainter({
    required Listenable repaint,
    required this.getStrokes,
    required this.getActiveStroke,
    this.renderer = const CanvasRenderer(),
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    renderer.render(
      canvas: canvas,
      size: size,
      strokes: getStrokes(),
      activeStroke: getActiveStroke(),
    );
  }

  @override
  bool shouldRepaint(covariant CanvasCustomPainter oldDelegate) => false;
}
