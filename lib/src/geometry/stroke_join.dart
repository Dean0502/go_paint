import 'dart:math' as math;
import 'dart:ui';
import 'geometry_math.dart';

/// Style of the interior and exterior corners (joins) of an outline stroke.
enum StrokeJoinType {
  /// Smooth rounded arc connecting adjacent segment boundaries.
  round,

  /// Straight flat bevel connecting adjacent segment boundaries.
  bevel,

  /// Sharp corner extending outer boundaries until they intersect.
  miter,
}

/// Generates join contours connecting boundaries at stroke vertices.
class StrokeJoinBuilder {
  StrokeJoinBuilder._();

  /// Builds join vertices for both the left and right boundaries at vertex [center].
  ///
  /// [vIn] is the incoming normalized direction vector ($C_i - C_{i-1}$).
  /// [vOut] is the outgoing normalized direction vector ($C_{i+1} - C_i$).
  static JoinResult buildJoin({
    required Offset center,
    required Offset vIn,
    required Offset vOut,
    required double radius,
    required StrokeJoinType joinType,
    double miterLimit = 4.0,
    int arcSteps = 6,
  }) {
    final nIn = GeometryMath.leftNormal(vIn);
    final nOut = GeometryMath.leftNormal(vOut);

    final lIn = center + nIn * radius;
    final lOut = center + nOut * radius;
    final rIn = center - nIn * radius;
    final rOut = center - nOut * radius;

    final cp = GeometryMath.cross(vIn, vOut);
    final dp = GeometryMath.dot(vIn, vOut);

    // Nearly straight / collinear segment
    if (cp.abs() < GeometryMath.epsilon || dp > 0.9999) {
      final avgNormal = GeometryMath.normalize(nIn + nOut);
      return JoinResult(
        leftPoints: [center + avgNormal * radius],
        rightPoints: [center - avgNormal * radius],
      );
    }

    // 180-degree complete turnaround
    if (dp < -0.9999) {
      // Reversal: left becomes right, arc around outer side
      return JoinResult(
        leftPoints: [lIn, lOut],
        rightPoints: [rIn, rOut],
      );
    }

    // Bisector normal and miter calculation
    final nSum = nIn + nOut;
    final nBisector = GeometryMath.normalize(nSum);
    // cos(theta / 2) between vIn and bisector
    final cosHalfAngle = GeometryMath.dot(nIn, nBisector).clamp(0.01, 1.0);
    final miterLength = radius / cosHalfAngle;
    final miterRatio = 1.0 / cosHalfAngle;

    if (cp > 0) {
      // Clockwise turn (turning to the right):
      // Left boundary is on the OUTSIDE.
      // Right boundary is on the INSIDE.
      final leftOuter = _buildOuterJoin(
        center: center,
        pIn: lIn,
        pOut: lOut,
        nIn: nIn,
        nOut: nOut,
        radius: radius,
        nBisector: nBisector,
        miterLength: miterLength,
        miterRatio: miterRatio,
        miterLimit: miterLimit,
        joinType: joinType,
        arcSteps: arcSteps,
        isLeft: true,
      );

      // Inner boundary: clamped miter intersection to avoid inward spike
      final innerPoint = center - nBisector * radius;
      return JoinResult(
        leftPoints: leftOuter,
        rightPoints: [rIn, innerPoint, rOut],
      );
    } else {
      // Counter-clockwise turn (turning to the left):
      // Right boundary is on the OUTSIDE.
      // Left boundary is on the INSIDE.
      final rightOuter = _buildOuterJoin(
        center: center,
        pIn: rIn,
        pOut: rOut,
        nIn: -nIn,
        nOut: -nOut,
        radius: radius,
        nBisector: -nBisector,
        miterLength: miterLength,
        miterRatio: miterRatio,
        miterLimit: miterLimit,
        joinType: joinType,
        arcSteps: arcSteps,
        isLeft: false,
      );

      // Inner boundary: clamped miter intersection
      final innerPoint = center + nBisector * radius;
      return JoinResult(
        leftPoints: [lIn, innerPoint, lOut],
        rightPoints: rightOuter,
      );
    }
  }

  static List<Offset> _buildOuterJoin({
    required Offset center,
    required Offset pIn,
    required Offset pOut,
    required Offset nIn,
    required Offset nOut,
    required double radius,
    required Offset nBisector,
    required double miterLength,
    required double miterRatio,
    required double miterLimit,
    required StrokeJoinType joinType,
    required int arcSteps,
    required bool isLeft,
  }) {
    switch (joinType) {
      case StrokeJoinType.bevel:
        return [pIn, pOut];

      case StrokeJoinType.miter:
        if (miterRatio <= miterLimit) {
          final miterPoint = center + nBisector * miterLength;
          return [pIn, miterPoint, pOut];
        } else {
          // Fallback to bevel if miter limit is exceeded
          return [pIn, pOut];
        }

      case StrokeJoinType.round:
        final angleIn = GeometryMath.angle(pIn - center);
        final angleOut = GeometryMath.angle(pOut - center);

        double sweep = angleOut - angleIn;
        if (isLeft) {
          // Clockwise turn: sweep should be positive
          while (sweep < 0) {
            sweep += 2 * math.pi;
          }
          if (sweep > math.pi) {
            sweep -= 2 * math.pi;
          }
        } else {
          // Counter-clockwise turn: sweep should be negative
          while (sweep > 0) {
            sweep -= 2 * math.pi;
          }
          if (sweep < -math.pi) {
            sweep += 2 * math.pi;
          }
        }

        return GeometryMath.arcPoints(
          center: center,
          radius: radius,
          startAngle: angleIn,
          sweepAngle: sweep,
          steps: arcSteps,
        );
    }
  }
}

/// Result of computing join vertices at a stroke corner.
class JoinResult {
  final List<Offset> leftPoints;
  final List<Offset> rightPoints;

  const JoinResult({
    required this.leftPoints,
    required this.rightPoints,
  });
}
