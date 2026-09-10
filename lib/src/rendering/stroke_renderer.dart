import 'package:flutter/material.dart';
import '../stroke/stroke.dart';
import '../stroke/stroke_point.dart';

/// Abstract contract for brush renderers.
///
/// Decouples the mathematical stroke engine from visual appearance, allowing
/// the exact same [Stroke] data to be rendered by different visual engines
/// (Ink, Pencil, Crayon, Marker, etc.).
abstract class StrokeRenderer {
  void render(Canvas canvas, Stroke stroke);
}

/// v0.1 Default Brush: Ultra-smooth, continuous black/colored ink line.
///
/// Produces:
/// - Smooth continuous Bézier line
/// - Round caps and round joins
/// - Zero gaps
/// - Zero visible point beads or overlap seams
/// - Zero angular corners
/// - Solid, consistent width
class BasicInkRenderer implements StrokeRenderer {
  const BasicInkRenderer();

  @override
  void render(Canvas canvas, Stroke stroke) {
    final points = stroke.points;
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.baseWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Single point tap: draw clean circle dot
    if (points.length == 1) {
      final fillPaint = Paint()
        ..color = stroke.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(points.first.position, stroke.baseWidth * 0.5, fillPaint);
      return;
    }

    // Continuous Bézier midpoint path
    final path = _buildContinuousPath(points);
    canvas.drawPath(path, paint);
  }

  Path _buildContinuousPath(List<StrokePoint> points) {
    final path = Path();
    final first = points[0].position;
    path.moveTo(first.dx, first.dy);

    if (points.length == 2) {
      final second = points[1].position;
      path.lineTo(second.dx, second.dy);
      return path;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i].position;
      final p1 = points[i + 1].position;
      final mid = Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    final last = points.last.position;
    path.lineTo(last.dx, last.dy);
    return path;
  }
}
