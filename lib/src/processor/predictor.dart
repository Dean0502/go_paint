import 'dart:math' as math;
import 'dart:ui';
import '../stroke/stroke_point.dart';
import 'stabilizer_config.dart';

/// Optional short-term point predictor for zero-latency fingertip tracking.
///
/// Disabled by default. When enabled, extrapolates the leading tip of the stroke
/// 1 frame ahead (e.g. 12-16ms) to eliminate perceived physical touchscreen lag.
///
/// CRITICAL: Predicted points are TRANSIENT and must never be committed to
/// permanent stroke history.
class Predictor {
  final StabilizerConfig config;

  Predictor({required this.config});

  /// Generates a single forward-predicted [StrokePoint] based on current [position],
  /// [direction] unit vector, and [velocity].
  StrokePoint? predictTip({
    required Offset position,
    required Offset direction,
    required double velocity,
    required double width,
    required double pressure,
    required Duration timestamp,
  }) {
    if (!config.predictionEnabled) return null;
    if (velocity < 60.0 || direction == Offset.zero) return null;

    final horizonSec = config.predictionHorizonMs / 1000.0;
    final idealDistance = velocity * horizonSec;
    final cappedDistance = math.min(idealDistance, config.maxPredictionDistance);

    if (cappedDistance < 1.0) return null;

    final predictedPos = Offset(
      position.dx + direction.dx * cappedDistance,
      position.dy + direction.dy * cappedDistance,
    );

    return StrokePoint(
      position: predictedPos,
      timestamp: timestamp + Duration(milliseconds: config.predictionHorizonMs.toInt()),
      pressure: pressure,
      width: width,
      velocity: velocity,
    );
  }
}
