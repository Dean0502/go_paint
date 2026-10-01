import 'package:flutter/material.dart';
import 'stroke_point.dart';

/// An immutable representation of a complete or in-progress stroke.
class Stroke {
  final String id;
  final List<StrokePoint> points;
  final Color color;
  final double baseWidth;
  final bool isComplete;
  final Rect bounds;
  Path? cachedPath;

  Stroke({
    required this.id,
    required this.points,
    this.color = Colors.black,
    this.baseWidth = 4.0,
    this.isComplete = false,
    Rect? bounds,
    this.cachedPath,
  }) : bounds = bounds ?? _computeBounds(points, baseWidth);

  static Rect _computeBounds(List<StrokePoint> points, double width) {
    if (points.isEmpty) return Rect.zero;

    double minX = points[0].position.dx;
    double maxX = points[0].position.dx;
    double minY = points[0].position.dy;
    double maxY = points[0].position.dy;

    for (int i = 1; i < points.length; i++) {
      final p = points[i].position;
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final pad = width * 0.5 + 4.0;
    return Rect.fromLTRB(
      minX - pad,
      minY - pad,
      maxX + pad,
      maxY + pad,
    );
  }

  Stroke copyWith({
    String? id,
    List<StrokePoint>? points,
    Color? color,
    double? baseWidth,
    bool? isComplete,
    Rect? bounds,
    Path? cachedPath,
  }) {
    final newPoints = points ?? this.points;
    final newWidth = baseWidth ?? this.baseWidth;
    return Stroke(
      id: id ?? this.id,
      points: newPoints,
      color: color ?? this.color,
      baseWidth: newWidth,
      isComplete: isComplete ?? this.isComplete,
      bounds: bounds ?? _computeBounds(newPoints, newWidth),
      cachedPath: cachedPath ?? this.cachedPath,
    );
  }
}
