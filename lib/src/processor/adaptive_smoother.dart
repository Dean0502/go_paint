import 'dart:ui';
import 'stabilizer_config.dart';

/// Applies velocity-adaptive low-pass streamline smoothing.
///
/// Slow movements receive higher smoothing to eliminate human tremor.
/// Fast sweeps receive minimal smoothing to eliminate perceived tracking latency.
class AdaptiveSmoother {
  final StabilizerConfig config;
  Offset? _smoothedPosition;

  AdaptiveSmoother({required this.config});

  Offset? get currentPosition => _smoothedPosition;

  void reset() {
    _smoothedPosition = null;
  }

  /// Calculates the effective streamline factor for the given [velocity].
  double computeStreamlineFactor(double velocity) {
    if (config.velocityMax <= config.velocityMin) return config.streamlineSlow;

    final t = ((velocity - config.velocityMin) /
            (config.velocityMax - config.velocityMin))
        .clamp(0.0, 1.0);

    // Lerp from slow streamline (high dampening) to fast streamline (low latency)
    return config.streamlineSlow +
        (config.streamlineFast - config.streamlineSlow) * t;
  }

  /// Filters [rawPosition] against current running position using [velocity] or [overrideFactor].
  Offset smooth(Offset rawPosition, double velocity, {double? overrideFactor}) {
    if (_smoothedPosition == null) {
      _smoothedPosition = rawPosition;
      return rawPosition;
    }

    final streamline = overrideFactor ?? computeStreamlineFactor(velocity);
    final followFactor = (1.0 - streamline).clamp(0.02, 1.0);

    _smoothedPosition = Offset(
      _smoothedPosition!.dx +
          (rawPosition.dx - _smoothedPosition!.dx) * followFactor,
      _smoothedPosition!.dy +
          (rawPosition.dy - _smoothedPosition!.dy) * followFactor,
    );

    return _smoothedPosition!;
  }
}
