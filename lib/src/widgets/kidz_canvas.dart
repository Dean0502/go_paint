import 'package:flutter/material.dart';
import '../controller/kidz_canvas_controller.dart';
import '../input/pointer_sample.dart';
import '../rendering/canvas_renderer.dart';

/// The interactive drawing canvas widget.
///
/// Handles high-frequency pointer capture with sub-pixel fidelity,
/// feeding samples to [KidzCanvasController].
class KidzCanvas extends StatelessWidget {
  final KidzCanvasController controller;
  final Color backgroundColor;
  final bool clipToBounds;

  const KidzCanvas({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.white,
    this.clipToBounds = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget canvasBody = RepaintBoundary(
      child: CustomPaint(
        painter: CanvasCustomPainter(
          repaint: controller,
          getStrokes: () => controller.strokes,
          getActiveStroke: () => controller.activeStroke,
          renderer: CanvasRenderer(strokeRenderer: controller.strokeRenderer),
        ),
        size: Size.infinite,
      ),
    );

    if (clipToBounds) {
      canvasBody = ClipRect(child: canvasBody);
    }

    return Container(
      color: backgroundColor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          controller.handlePointerDown(PointerSample.fromPointerEvent(event));
        },
        onPointerMove: (event) {
          controller.handlePointerMove(PointerSample.fromPointerEvent(event));
        },
        onPointerUp: (event) {
          controller.handlePointerUp(PointerSample.fromPointerEvent(event));
        },
        onPointerCancel: (event) {
          controller.handlePointerCancel(PointerSample.fromPointerEvent(event));
        },
        child: canvasBody,
      ),
    );
  }
}

/// Package-level alias for [KidzCanvas].
typedef GoPaint = KidzCanvas;
