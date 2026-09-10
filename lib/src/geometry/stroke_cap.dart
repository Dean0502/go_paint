import 'dart:math' as math;
import 'dart:ui';
import 'geometry_math.dart';

/// Style of the endpoints (caps) of an outline stroke.
enum StrokeCapType {
  /// Semi-circular cap extending half the stroke width beyond the endpoint.
  round,

  /// Flat edge perpendicular to the stroke direction at the exact endpoint.
  butt,

  /// Square cap extending half the stroke width beyond the endpoint.
  square,
}

/// Generates cap contours connecting boundaries at stroke extremities.
class StrokeCapBuilder {
  StrokeCapBuilder._();

  /// Generates points for the start cap connecting right point [r] to left point [l].
  ///
  /// The stroke starts at [center], with forward tangent [tangent] and radius [radius].
  static List<Offset> buildStartCap({
    required Offset center,
    required Offset tangent,
    required Offset l,
    required Offset r,
    required double radius,
    required StrokeCapType capType,
    int steps = 8,
  }) {
    if (radius <= 0) return [r, l];

    switch (capType) {
      case StrokeCapType.butt:
        return [r, l];

      case StrokeCapType.square:
        final back = -tangent * radius;
        return [
          r,
          r + back,
          l + back,
          l,
        ];

      case StrokeCapType.round:
        // Arc from r (-leftNormal) around center towards -tangent, ending at l (+leftNormal)
        final angleR = GeometryMath.angle(r - center);
        final angleL = GeometryMath.angle(l - center);

        // Sweep angle from angleR to angleL passing through -tangent
        double sweep = angleL - angleR;
        while (sweep <= 0) {
          sweep += 2 * math.pi;
        }
        // Verify whether this sweep passes through -tangent; if not, invert
        final backAngle = GeometryMath.angle(-tangent);
        double diff = (backAngle - angleR) % (2 * math.pi);
        if (diff < 0) diff += 2 * math.pi;

        if (diff > sweep) {
          sweep -= 2 * math.pi;
        }

        return GeometryMath.arcPoints(
          center: center,
          radius: radius,
          startAngle: angleR,
          sweepAngle: sweep,
          steps: steps,
        );
    }
  }

  /// Generates points for the end cap connecting left point [l] to right point [r].
  ///
  /// The stroke ends at [center], with forward tangent [tangent] and radius [radius].
  static List<Offset> buildEndCap({
    required Offset center,
    required Offset tangent,
    required Offset l,
    required Offset r,
    required double radius,
    required StrokeCapType capType,
    int steps = 8,
  }) {
    if (radius <= 0) return [l, r];

    switch (capType) {
      case StrokeCapType.butt:
        return [l, r];

      case StrokeCapType.square:
        final forward = tangent * radius;
        return [
          l,
          l + forward,
          r + forward,
          r,
        ];

      case StrokeCapType.round:
        // Arc from l (+leftNormal) around center towards +tangent, ending at r (-leftNormal)
        final angleL = GeometryMath.angle(l - center);
        final angleR = GeometryMath.angle(r - center);

        double sweep = angleR - angleL;
        while (sweep <= 0) {
          sweep += 2 * math.pi;
        }

        final forwardAngle = GeometryMath.angle(tangent);
        double diff = (forwardAngle - angleL) % (2 * math.pi);
        if (diff < 0) diff += 2 * math.pi;

        if (diff > sweep) {
          sweep -= 2 * math.pi;
        }

        return GeometryMath.arcPoints(
          center: center,
          radius: radius,
          startAngle: angleL,
          sweepAngle: sweep,
          steps: steps,
        );
    }
  }
}
