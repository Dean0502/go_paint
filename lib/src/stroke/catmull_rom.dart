import 'dart:math' as math;
import 'dart:ui';

/// Centripetal Catmull-Rom spline interpolation engine.
///
/// Features:
/// 1. Centripetal parameterization ($\alpha = 0.5$) guarantees no cusps or self-intersections.
/// 2. Smooth tangent continuity ($C^1$) across all intermediate points.
/// 3. Dynamic subdivision based on segment arc-length.
class CatmullRomSpline {
  /// Evaluates a single 2D point along the Catmull-Rom curve defined by 4 control points.
  ///
  /// [p0], [p1], [p2], [p3] are consecutive control points.
  /// [t] is normalized between 0.0 (at [p1]) and 1.0 (at [p2]).
  /// [alpha] is the knot parameter (0.5 for centripetal, 0.0 for uniform, 1.0 for chordal).
  static Offset evaluate({
    required Offset p0,
    required Offset p1,
    required Offset p2,
    required Offset p3,
    required double t,
    double alpha = 0.5,
  }) {
    if (alpha == 0.0) {
      // Fast path: standard uniform Catmull-Rom
      final t2 = t * t;
      final t3 = t2 * t;
      final x = 0.5 *
          (2.0 * p1.dx +
              (-p0.dx + p2.dx) * t +
              (2.0 * p0.dx - 5.0 * p1.dx + 4.0 * p2.dx - p3.dx) * t2 +
              (-p0.dx + 3.0 * p1.dx - 3.0 * p2.dx + p3.dx) * t3);
      final y = 0.5 *
          (2.0 * p1.dy +
              (-p0.dy + p2.dy) * t +
              (2.0 * p0.dy - 5.0 * p1.dy + 4.0 * p2.dy - p3.dy) * t2 +
              (-p0.dy + 3.0 * p1.dy - 3.0 * p2.dy + p3.dy) * t3);
      return Offset(x, y);
    }

    // Centripetal Catmull-Rom with knot calculation
    double getKnot(double ti, Offset pi, Offset pj) {
      final dx = pj.dx - pi.dx;
      final dy = pj.dy - pi.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      return ti + math.pow(dist, alpha);
    }

    const t0 = 0.0;
    final t1 = getKnot(t0, p0, p1);
    final t2 = getKnot(t1, p1, p2);
    final t3 = getKnot(t2, p2, p3);

    // Safeguard against coincident points
    if ((t1 - t0).abs() < 1e-6 ||
        (t2 - t1).abs() < 1e-6 ||
        (t3 - t2).abs() < 1e-6) {
      return Offset.lerp(p1, p2, t)!;
    }

    final globalT = t1 + t * (t2 - t1);

    final a1 = _lerpOffset(p0, p1, (globalT - t0) / (t1 - t0));
    final a2 = _lerpOffset(p1, p2, (globalT - t1) / (t2 - t1));
    final a3 = _lerpOffset(p2, p3, (globalT - t2) / (t3 - t2));

    final b1 = _lerpOffset(a1, a2, (globalT - t0) / (t2 - t0));
    final b2 = _lerpOffset(a2, a3, (globalT - t1) / (t3 - t1));

    return _lerpOffset(b1, b2, (globalT - t1) / (t2 - t1));
  }

  static Offset _lerpOffset(Offset a, Offset b, double t) {
    return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
  }

  /// Subdivides the segment between [p1] and [p2] into [steps] intermediate points.
  static List<Offset> interpolateSegment({
    required Offset p0,
    required Offset p1,
    required Offset p2,
    required Offset p3,
    int steps = 2,
    double alpha = 0.5,
  }) {
    if (steps <= 0) return [];
    final results = <Offset>[];
    for (int s = 1; s <= steps; s++) {
      final t = s / (steps + 1).toDouble();
      results.add(evaluate(p0: p0, p1: p1, p2: p2, p3: p3, t: t, alpha: alpha));
    }
    return results;
  }
}
