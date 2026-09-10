import 'dart:math' as math;
import '../stroke/stroke_point.dart';

/// Configuration for calculating stroke width dynamics from pressure and velocity.
class StrokeWidthConfig {
  final double baseWidth;
  final bool pressureEnabled;
  final bool velocityEnabled;
  final double minWidthFactor;
  final double maxWidthFactor;
  final double pressureGamma;
  final double velocityMin;
  final double velocityMax;
  final double velocityFactorSlow;
  final double velocityFactorFast;

  const StrokeWidthConfig({
    this.baseWidth = 8.0,
    this.pressureEnabled = false,
    this.velocityEnabled = false,
    this.minWidthFactor = 0.7,
    this.maxWidthFactor = 1.3,
    this.pressureGamma = 1.0,
    this.velocityMin = 100.0,
    this.velocityMax = 1000.0,
    this.velocityFactorSlow = 1.2,
    this.velocityFactorFast = 0.8,
  }) : assert(baseWidth >= 0.0, 'baseWidth must be non-negative'),
       assert(minWidthFactor >= 0.0, 'minWidthFactor must be non-negative'),
       assert(maxWidthFactor >= minWidthFactor, 'maxWidthFactor must be >= minWidthFactor');

  /// Creates a constant-width configuration.
  const StrokeWidthConfig.constant(double width)
      : baseWidth = width,
        pressureEnabled = false,
        velocityEnabled = false,
        minWidthFactor = 1.0,
        maxWidthFactor = 1.0,
        pressureGamma = 1.0,
        velocityMin = 100.0,
        velocityMax = 1000.0,
        velocityFactorSlow = 1.0,
        velocityFactorFast = 1.0;

  StrokeWidthConfig copyWith({
    double? baseWidth,
    bool? pressureEnabled,
    bool? velocityEnabled,
    double? minWidthFactor,
    double? maxWidthFactor,
    double? pressureGamma,
    double? velocityMin,
    double? velocityMax,
    double? velocityFactorSlow,
    double? velocityFactorFast,
  }) {
    return StrokeWidthConfig(
      baseWidth: baseWidth ?? this.baseWidth,
      pressureEnabled: pressureEnabled ?? this.pressureEnabled,
      velocityEnabled: velocityEnabled ?? this.velocityEnabled,
      minWidthFactor: minWidthFactor ?? this.minWidthFactor,
      maxWidthFactor: maxWidthFactor ?? this.maxWidthFactor,
      pressureGamma: pressureGamma ?? this.pressureGamma,
      velocityMin: velocityMin ?? this.velocityMin,
      velocityMax: velocityMax ?? this.velocityMax,
      velocityFactorSlow: velocityFactorSlow ?? this.velocityFactorSlow,
      velocityFactorFast: velocityFactorFast ?? this.velocityFactorFast,
    );
  }
}

/// Abstract contract for computing geometric stroke width at any point along a centerline.
abstract class StrokeWidthProfile {
  const StrokeWidthProfile();

  /// Calculates the full stroke diameter (width) in logical pixels for [point].
  double getWidth(StrokePoint point);

  /// Calculates the stroke radius (half-width) for [point].
  double getRadius(StrokePoint point) {
    final w = getWidth(point);
    return math.max(0.0, w * 0.5);
  }
}

/// A constant-width profile that returns the exact same width for every point.
class ConstantWidthProfile extends StrokeWidthProfile {
  final double width;

  const ConstantWidthProfile(this.width);

  @override
  double getWidth(StrokePoint point) => math.max(0.0, width);
}

/// A configurable profile that modulates width based on hardware/simulated pressure and kinematics velocity.
class DynamicWidthProfile extends StrokeWidthProfile {
  final StrokeWidthConfig config;

  const DynamicWidthProfile(this.config);

  @override
  double getWidth(StrokePoint point) {
    if (config.baseWidth <= 0.0) return 0.0;

    double pressureFactor = 1.0;
    if (config.pressureEnabled) {
      final clampedP = point.pressure.clamp(0.0, 1.0);
      final shapedP = math.pow(clampedP, config.pressureGamma).toDouble();
      // Map pressure 0.0..1.0 to minWidthFactor..maxWidthFactor
      pressureFactor = config.minWidthFactor + shapedP * (config.maxWidthFactor - config.minWidthFactor);
    }

    double velocityFactor = 1.0;
    if (config.velocityEnabled) {
      final v = point.velocity.clamp(config.velocityMin, config.velocityMax);
      final t = (config.velocityMax > config.velocityMin)
          ? (v - config.velocityMin) / (config.velocityMax - config.velocityMin)
          : 0.0;
      // Slow movement -> velocityFactorSlow; Fast movement -> velocityFactorFast
      velocityFactor = config.velocityFactorSlow + t * (config.velocityFactorFast - config.velocityFactorSlow);
    }

    final computed = config.baseWidth * pressureFactor * velocityFactor;
    final minW = config.baseWidth * config.minWidthFactor;
    final maxW = config.baseWidth * config.maxWidthFactor;

    return computed.clamp(minW, maxW).clamp(0.0, double.infinity);
  }
}
