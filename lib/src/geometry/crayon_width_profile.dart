import 'dart:math' as math;
import '../stroke/stroke_point.dart';
import 'stroke_width_profile.dart';

/// Configuration for the Crayon brush width dynamics.
class CrayonWidthConfig {
  /// Base stroke width in logical pixels.
  final double baseWidth;

  /// Lower bound scalar for stroke width (e.g. 0.70 = 70% of baseWidth).
  final double minWidthFactor;

  /// Upper bound scalar for stroke width (e.g. 1.40 = 140% of baseWidth).
  final double maxWidthFactor;

  /// Minimum velocity threshold (px/sec) where slow expansion begins.
  final double velocityMin;

  /// Maximum velocity threshold (px/sec) where fast tapering saturates.
  final double velocityMax;

  /// Width multiplier at slow drawing speeds (< velocityMin).
  final double velocitySlowFactor;

  /// Width multiplier at fast drawing speeds (> velocityMax).
  final double velocityFastFactor;

  /// Width multiplier at lightest touch (pressure ~0.0).
  final double pressureLightFactor;

  /// Width multiplier at firmest press (pressure ~1.0).
  final double pressureFirmFactor;

  /// Gamma curve applied to pressure (1.0 = linear).
  final double pressureGamma;

  /// Number of points at stroke start/end where subtle taper is applied.
  final int taperPoints;

  /// Initial width scalar at the very first point of entry taper.
  final double startTaperFactor;

  /// Final width scalar at the terminal point of exit taper.
  final double endTaperFactor;

  /// Exponential smoothing factor (0.0 to 1.0) between consecutive points.
  final double smoothingFactor;

  const CrayonWidthConfig({
    this.baseWidth = 12.0,
    this.minWidthFactor = 0.70,
    this.maxWidthFactor = 1.40,
    this.velocityMin = 100.0,
    this.velocityMax = 1000.0,
    this.velocitySlowFactor = 1.20,
    this.velocityFastFactor = 0.80,
    this.pressureLightFactor = 0.75,
    this.pressureFirmFactor = 1.35,
    this.pressureGamma = 1.0,
    this.taperPoints = 3,
    this.startTaperFactor = 0.75,
    this.endTaperFactor = 0.70,
    this.smoothingFactor = 0.40,
  })  : assert(baseWidth >= 0.0, 'baseWidth must be non-negative'),
        assert(minWidthFactor >= 0.0, 'minWidthFactor must be non-negative'),
        assert(maxWidthFactor >= minWidthFactor, 'maxWidthFactor must be >= minWidthFactor'),
        assert(velocityMax >= velocityMin, 'velocityMax must be >= velocityMin'),
        assert(smoothingFactor > 0.0 && smoothingFactor <= 1.0, 'smoothingFactor must be in (0, 1]');

  CrayonWidthConfig copyWith({
    double? baseWidth,
    double? minWidthFactor,
    double? maxWidthFactor,
    double? velocityMin,
    double? velocityMax,
    double? velocitySlowFactor,
    double? velocityFastFactor,
    double? pressureLightFactor,
    double? pressureFirmFactor,
    double? pressureGamma,
    int? taperPoints,
    double? startTaperFactor,
    double? endTaperFactor,
    double? smoothingFactor,
  }) {
    return CrayonWidthConfig(
      baseWidth: baseWidth ?? this.baseWidth,
      minWidthFactor: minWidthFactor ?? this.minWidthFactor,
      maxWidthFactor: maxWidthFactor ?? this.maxWidthFactor,
      velocityMin: velocityMin ?? this.velocityMin,
      velocityMax: velocityMax ?? this.velocityMax,
      velocitySlowFactor: velocitySlowFactor ?? this.velocitySlowFactor,
      velocityFastFactor: velocityFastFactor ?? this.velocityFastFactor,
      pressureLightFactor: pressureLightFactor ?? this.pressureLightFactor,
      pressureFirmFactor: pressureFirmFactor ?? this.pressureFirmFactor,
      pressureGamma: pressureGamma ?? this.pressureGamma,
      taperPoints: taperPoints ?? this.taperPoints,
      startTaperFactor: startTaperFactor ?? this.startTaperFactor,
      endTaperFactor: endTaperFactor ?? this.endTaperFactor,
      smoothingFactor: smoothingFactor ?? this.smoothingFactor,
    );
  }
}

/// Computes per-point radii for Crayon strokes before geometry generation.
///
/// Features wax contact flattening dynamics, velocity dwell scaling,
/// and gentle endpoint tapering.
class CrayonWidthProfile extends StrokeWidthProfile {
  final CrayonWidthConfig config;

  const CrayonWidthProfile([this.config = const CrayonWidthConfig()]);

  @override
  double getWidth(StrokePoint point) {
    return computeRawWidth(point, config.baseWidth);
  }

  /// Computes raw point width from velocity and pressure before sequence smoothing.
  double computeRawWidth(StrokePoint point, double effectiveBaseWidth) {
    if (effectiveBaseWidth <= 0.0) return 0.0;

    // 1. Velocity factor
    double velocityFactor = 1.0;
    if (config.velocityMax > config.velocityMin) {
      final v = point.velocity.clamp(config.velocityMin, config.velocityMax);
      final t = (v - config.velocityMin) / (config.velocityMax - config.velocityMin);
      velocityFactor = config.velocitySlowFactor + t * (config.velocityFastFactor - config.velocitySlowFactor);
    }

    // 2. Pressure factor (wax flattening under firm pressure)
    final clampedP = point.pressure.clamp(0.0, 1.0);
    final shapedP = math.pow(clampedP, config.pressureGamma).toDouble();
    final pressureFactor = config.pressureLightFactor +
        shapedP * (config.pressureFirmFactor - config.pressureLightFactor);

    final raw = effectiveBaseWidth * velocityFactor * pressureFactor;
    final minW = effectiveBaseWidth * config.minWidthFactor;
    final maxW = effectiveBaseWidth * config.maxWidthFactor;

    return raw.clamp(minW, maxW).clamp(0.0, double.infinity);
  }

  /// Computes the complete list of smoothed and tapered radii for each [StrokePoint].
  List<double> computeRadii(
    List<StrokePoint> points, {
    double? baseWidth,
    bool isComplete = true,
  }) {
    if (points.isEmpty) return const [];

    final effectiveBaseWidth = baseWidth ?? config.baseWidth;
    if (effectiveBaseWidth <= 0.0) {
      return List<double>.filled(points.length, 0.0);
    }

    // Single-point dab
    if (points.length == 1) {
      final w = computeRawWidth(points.first, effectiveBaseWidth);
      return [math.max(0.0, w * 0.5)];
    }

    // 1. Compute raw width sequence
    final rawWidths = List<double>.generate(
      points.length,
      (i) => computeRawWidth(points[i], effectiveBaseWidth),
      growable: false,
    );

    // 2. Apply exponential smoothing to eliminate high-frequency input jitter
    final smoothed = List<double>.filled(points.length, 0.0);
    smoothed[0] = rawWidths[0];
    final alpha = config.smoothingFactor.clamp(0.05, 1.0);

    for (int i = 1; i < points.length; i++) {
      smoothed[i] = (1.0 - alpha) * smoothed[i - 1] + alpha * rawWidths[i];
    }

    // 3. Apply subtle entry and exit taper
    final taperCount = config.taperPoints;
    final minW = effectiveBaseWidth * config.minWidthFactor;
    final maxW = effectiveBaseWidth * config.maxWidthFactor;

    final radii = List<double>.filled(points.length, 0.0);
    for (int i = 0; i < points.length; i++) {
      double width = smoothed[i];

      // Entry taper
      if (taperCount > 0 && i < taperCount) {
        final t = i / taperCount;
        final factor = config.startTaperFactor + t * (1.0 - config.startTaperFactor);
        width *= factor;
      }

      // Exit taper (only applied when stroke is complete)
      final distFromEnd = points.length - 1 - i;
      if (isComplete && taperCount > 0 && distFromEnd < taperCount) {
        final t = distFromEnd / taperCount;
        final factor = config.endTaperFactor + t * (1.0 - config.endTaperFactor);
        width *= factor;
      }

      final clampedW = width.clamp(minW * 0.5, maxW).clamp(0.0, double.infinity);
      radii[i] = math.max(0.0, clampedW * 0.5);
    }

    return radii;
  }
}
