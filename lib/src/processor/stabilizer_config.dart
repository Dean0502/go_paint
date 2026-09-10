/// Comprehensive configuration parameters for the modular input processor.
///
/// Every threshold is exposed as a tunable property so it can be calibrated
/// directly on target Android/iOS hardware rather than hardcoded.
class StabilizerConfig {
  /// Minimum displacement (in logical pixels) to reject micro-jitter and hardware tremors.
  final double minDistance;

  /// Lower velocity bound (px/sec) where slow, deliberate handwriting occurs.
  final double velocityMin;

  /// Upper velocity bound (px/sec) where fast, expressive drawing occurs.
  final double velocityMax;

  /// Streamline factor applied at slow speeds (higher = more tremor suppression).
  final double streamlineSlow;

  /// Streamline factor applied at fast speeds (lower = lower latency, tighter tracking).
  final double streamlineFast;

  /// Direction deviation threshold (in degrees) that triggers corner smoothing reduction.
  final double cornerAngleDeg;

  /// Streamline factor applied during acute corner turns to preserve apex definition.
  final double cornerSmoothingFactor;

  /// Whether short-term 1-frame point prediction is enabled.
  /// Disabled by default to prevent pulling ahead of finger during initial testing.
  final bool predictionEnabled;

  /// Time horizon (in milliseconds) for predictive extrapolation (typically ~1 frame = 12-16ms).
  final double predictionHorizonMs;

  /// Safety cap (in logical pixels) limiting how far ahead a point can be predicted.
  final double maxPredictionDistance;

  /// Displacement distance between points that activates Catmull-Rom curve subdivision.
  final double catmullThreshold;

  /// Number of intermediate points inserted when Catmull-Rom subdivision is active.
  final int catmullSteps;

  const StabilizerConfig({
    this.minDistance = 1.5,
    this.velocityMin = 120.0,
    this.velocityMax = 800.0,
    this.streamlineSlow = 0.45,
    this.streamlineFast = 0.08,
    this.cornerAngleDeg = 65.0,
    this.cornerSmoothingFactor = 0.12,
    this.predictionEnabled = false,
    this.predictionHorizonMs = 16.0,
    this.maxPredictionDistance = 15.0,
    this.catmullThreshold = 14.0,
    this.catmullSteps = 2,
  });

  StabilizerConfig copyWith({
    double? minDistance,
    double? velocityMin,
    double? velocityMax,
    double? streamlineSlow,
    double? streamlineFast,
    double? cornerAngleDeg,
    double? cornerSmoothingFactor,
    bool? predictionEnabled,
    double? predictionHorizonMs,
    double? maxPredictionDistance,
    double? catmullThreshold,
    int? catmullSteps,
  }) {
    return StabilizerConfig(
      minDistance: minDistance ?? this.minDistance,
      velocityMin: velocityMin ?? this.velocityMin,
      velocityMax: velocityMax ?? this.velocityMax,
      streamlineSlow: streamlineSlow ?? this.streamlineSlow,
      streamlineFast: streamlineFast ?? this.streamlineFast,
      cornerAngleDeg: cornerAngleDeg ?? this.cornerAngleDeg,
      cornerSmoothingFactor: cornerSmoothingFactor ?? this.cornerSmoothingFactor,
      predictionEnabled: predictionEnabled ?? this.predictionEnabled,
      predictionHorizonMs: predictionHorizonMs ?? this.predictionHorizonMs,
      maxPredictionDistance: maxPredictionDistance ?? this.maxPredictionDistance,
      catmullThreshold: catmullThreshold ?? this.catmullThreshold,
      catmullSteps: catmullSteps ?? this.catmullSteps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minDistance': minDistance,
      'velocityMin': velocityMin,
      'velocityMax': velocityMax,
      'streamlineSlow': streamlineSlow,
      'streamlineFast': streamlineFast,
      'cornerAngleDeg': cornerAngleDeg,
      'cornerSmoothingFactor': cornerSmoothingFactor,
      'predictionEnabled': predictionEnabled,
      'predictionHorizonMs': predictionHorizonMs,
      'maxPredictionDistance': maxPredictionDistance,
      'catmullThreshold': catmullThreshold,
      'catmullSteps': catmullSteps,
    };
  }

  factory StabilizerConfig.fromJson(Map<String, dynamic> json) {
    return StabilizerConfig(
      minDistance: (json['minDistance'] as num?)?.toDouble() ?? 1.5,
      velocityMin: (json['velocityMin'] as num?)?.toDouble() ?? 120.0,
      velocityMax: (json['velocityMax'] as num?)?.toDouble() ?? 800.0,
      streamlineSlow: (json['streamlineSlow'] as num?)?.toDouble() ?? 0.45,
      streamlineFast: (json['streamlineFast'] as num?)?.toDouble() ?? 0.08,
      cornerAngleDeg: (json['cornerAngleDeg'] as num?)?.toDouble() ?? 65.0,
      cornerSmoothingFactor: (json['cornerSmoothingFactor'] as num?)?.toDouble() ?? 0.12,
      predictionEnabled: json['predictionEnabled'] as bool? ?? false,
      predictionHorizonMs: (json['predictionHorizonMs'] as num?)?.toDouble() ?? 16.0,
      maxPredictionDistance: (json['maxPredictionDistance'] as num?)?.toDouble() ?? 15.0,
      catmullThreshold: (json['catmullThreshold'] as num?)?.toDouble() ?? 14.0,
      catmullSteps: (json['catmullSteps'] as num?)?.toInt() ?? 2,
    );
  }
}
