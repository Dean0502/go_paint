import 'dart:math' as math;
import 'dart:ui';

/// High-performance, pure-Dart 2D mathematical utilities for stroke geometry generation.
class GeometryMath {
  GeometryMath._();

  static const double epsilon = 1e-6;

  /// Returns the Euclidean length of vector [v].
  static double length(Offset v) => math.sqrt(v.dx * v.dx + v.dy * v.dy);

  /// Returns the squared Euclidean length of vector [v].
  static double lengthSquared(Offset v) => v.dx * v.dx + v.dy * v.dy;

  /// Returns the distance between point [a] and point [b].
  static double distance(Offset a, Offset b) => length(b - a);

  /// Returns the normalized unit vector in direction [v].
  /// Returns [Offset.zero] if vector length is negligible.
  static Offset normalize(Offset v) {
    final len = length(v);
    if (len < epsilon) return Offset.zero;
    return Offset(v.dx / len, v.dy / len);
  }

  /// Computes the 2D dot product of [a] and [b].
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// Computes the 2D cross product ($a_x b_y - a_y b_x$).
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  /// Computes the left-hand perpendicular normal vector to direction [v]
  /// in Flutter's canvas coordinate space (Y down).
  ///
  /// For a vector pointing right (1, 0), the left normal points up (0, -1).
  static Offset leftNormal(Offset v) {
    final unit = normalize(v);
    return Offset(unit.dy, -unit.dx);
  }

  /// Computes the right-hand perpendicular normal vector to direction [v].
  static Offset rightNormal(Offset v) {
    final unit = normalize(v);
    return Offset(-unit.dy, unit.dx);
  }

  /// Computes the angle in radians of vector [v] relative to positive X-axis.
  static double angle(Offset v) => math.atan2(v.dy, v.dx);

  /// Computes the signed angle in radians from vector [u] to vector [v].
  static double signedAngleBetween(Offset u, Offset v) {
    return math.atan2(cross(u, v), dot(u, v));
  }

  /// Finds the intersection point of two lines defined by points (p1 -> p2) and (p3 -> p4).
  /// Returns null if lines are parallel or degenerate.
  static Offset? intersectLines(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denominator = cross(d1, d2);

    if (denominator.abs() < epsilon) {
      return null; // Parallel or collinear
    }

    final d13 = p1 - p3;
    final t = cross(d2, d13) / denominator;
    return Offset(p1.dx + t * d1.dx, p1.dy + t * d1.dy);
  }

  /// Generates sample points along a circular arc from [startAngle] with sweep [sweepAngle].
  static List<Offset> arcPoints({
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    int steps = 8,
  }) {
    if (radius <= 0 || steps < 1 || sweepAngle.abs() < epsilon) {
      return [
        Offset(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        ),
      ];
    }

    final result = <Offset>[];
    final stepAngle = sweepAngle / steps;

    for (int i = 0; i <= steps; i++) {
      final a = startAngle + i * stepAngle;
      result.add(Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      ));
    }

    return result;
  }
}
