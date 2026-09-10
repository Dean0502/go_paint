import 'package:flutter/material.dart';
import '../geometry/stroke_geometry_builder.dart';
import '../geometry/stroke_outline.dart';
import '../stroke/stroke.dart';
import 'stroke_renderer.dart';

/// Geometry-aware stroke renderer that generates and renders a closed continuous [StrokeOutline].
///
/// Features optional visual diagnostics to inspect:
/// - [fillOutline]: Filled 2D polygon with the stroke color.
/// - [showOutline]: Stroke contour outline border.
/// - [showCenterline]: The underlying smoothed centerline.
/// - [showBoundaries]: Color-coded left (green) and right (orange) boundary offsets.
class OutlineInkRenderer implements StrokeRenderer {
  final StrokeGeometryBuilder geometryBuilder;
  final bool fillOutline;
  final bool showOutline;
  final bool showCenterline;
  final bool showBoundaries;

  const OutlineInkRenderer({
    this.geometryBuilder = const StrokeGeometryBuilder(),
    this.fillOutline = true,
    this.showOutline = false,
    this.showCenterline = false,
    this.showBoundaries = false,
  });

  /// Computes the [StrokeOutline] for a stroke.
  StrokeOutline computeOutline(Stroke stroke) => geometryBuilder.build(stroke);

  @override
  void render(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final outline = geometryBuilder.build(stroke);
    if (outline.isEmpty) return;

    // 1. Fill outline
    if (fillOutline) {
      final fillPaint = Paint()
        ..color = stroke.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(outline.path, fillPaint);
    }

    // 2. Stroke contour border
    if (showOutline) {
      final strokePaint = Paint()
        ..color = stroke.color.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      canvas.drawPath(outline.path, strokePaint);
    }

    // 3. Diagnostic boundaries
    if (showBoundaries) {
      final leftPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      final rightPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true;

      _drawPolyline(canvas, outline.leftBoundary, leftPaint);
      _drawPolyline(canvas, outline.rightBoundary, rightPaint);
    }

    // 4. Diagnostic centerline
    if (showCenterline) {
      final centerPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      _drawPolyline(canvas, outline.centerline, centerPaint);
    }
  }

  void _drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }
}
