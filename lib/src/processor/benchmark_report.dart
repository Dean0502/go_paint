import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'stabilizer_config.dart';
import 'stroke_geometry_analyzer.dart';

/// Detailed quantitative benchmark report for a single gesture or drawing session.
///
/// Records hardware digitizer behavior, temporal delta statistics, velocity profiles,
/// processing latency estimates, corner apex deviation, and platform telemetry.
///
/// NOTE: [estimatedProcessingLatencyMs] is an internal comparative estimate of algorithm
/// filter group delay and digitizer period, NOT a physical touch-to-photon latency measurement.
class StrokeBenchmarkReport {
  /// Operating system platform (e.g. "android", "macos", "ios").
  final String platform;

  /// Android OS version and SDK level (e.g. "14 (SDK 34)"), or null if non-Android.
  final String? androidVersion;

  /// Human-readable device model and manufacturer (e.g. "Google Pixel 8").
  final String device;

  /// Host CPU architecture if available (e.g. "arm64-v8a").
  final String? cpuArchitecture;

  /// Measured hardware screen refresh rate in Hertz, or null if not reliably obtainable.
  final double? refreshRate;

  /// Screen pixel ratio (e.g. 2.625, 3.0).
  final double devicePixelRatio;

  /// Screen resolution description (physical and logical).
  final String screenResolution;

  /// Name of the standardized test mode (e.g. "fast_scribble", "slow_handwriting").
  final String test;

  /// Total count of raw hardware touch samples received from the digitizer.
  final int rawPoints;

  /// Total count of smoothed and interpolated points committed to the stroke.
  final int processedPoints;

  /// Average velocity across the stroke movement in logical pixels per second.
  final double averageVelocity;

  /// Maximum instantaneous velocity achieved during the stroke in px/s.
  final double maxVelocity;

  /// Average interval (\Delta t) between consecutive raw touch events in milliseconds.
  final double averageDeltaMs;

  /// Internal algorithmic processing delay estimate in milliseconds.
  ///
  /// IMPORTANT: This is a comparative estimate of sample interval and low-pass filter
  /// group delay, NOT a physical touch-to-photon display latency measurement.
  final double estimatedProcessingLatencyMs;

  /// Backwards-compatible alias for [estimatedProcessingLatencyMs].
  double get latencyEstimateMs => estimatedProcessingLatencyMs;

  /// Average streamline factor applied across all samples in the stroke (0.0 to 1.0).
  final double smoothingAmount;

  /// Measured distance (in logical px) between raw corner apex and smoothed curve.
  /// Null if no genuine corner was detected in the stroke (0.0 strictly indicates measured zero deviation).
  final double? cornerDeviationPx;

  /// Average orthogonal deviation (in logical px) between raw samples and the processed path.
  /// Measures general curve and straight-line fidelity against the finger trajectory.
  final double averageDeviationPx;

  /// Maximum orthogonal deviation (in logical px) between raw samples and the processed path.
  final double maxDeviationPx;

  /// Maximum distance (in logical px) extrapolated ahead by the predictor.
  final double predictionDistancePx;

  /// Whether point prediction was active during this test.
  final bool prediction;

  /// The exact [StabilizerConfig] parameters used during this benchmark run.
  final StabilizerConfig config;

  /// Comprehensive geometric analysis comparing raw input and processed path.
  final StrokeGeometryReport? geometry;

  /// Timestamp when the benchmark was completed.
  final DateTime timestamp;

  const StrokeBenchmarkReport({
    this.platform = 'unknown',
    this.androidVersion,
    required this.device,
    this.cpuArchitecture,
    this.refreshRate,
    this.devicePixelRatio = 1.0,
    this.screenResolution = 'unknown',
    required this.test,
    required this.rawPoints,
    required this.processedPoints,
    required this.averageVelocity,
    required this.maxVelocity,
    required this.averageDeltaMs,
    required this.estimatedProcessingLatencyMs,
    required this.smoothingAmount,
    this.cornerDeviationPx,
    this.averageDeviationPx = 0.0,
    this.maxDeviationPx = 0.0,
    required this.predictionDistancePx,
    required this.prediction,
    required this.config,
    this.geometry,
    required this.timestamp,
  });

  /// Serializes report to a JSON-compatible map matching benchmark requirements.
  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      if (androidVersion != null) 'androidVersion': androidVersion,
      'device': device,
      if (cpuArchitecture != null) 'cpuArchitecture': cpuArchitecture,
      'refreshRate': refreshRate != null
          ? (refreshRate!.roundToDouble() == refreshRate
              ? refreshRate!.toInt()
              : double.parse(refreshRate!.toStringAsFixed(1)))
          : null,
      'devicePixelRatio': double.parse(devicePixelRatio.toStringAsFixed(2)),
      'screenResolution': screenResolution,
      'test': test,
      'rawPoints': rawPoints,
      'processedPoints': processedPoints,
      'averageVelocity': double.parse(averageVelocity.toStringAsFixed(1)),
      'maxVelocity': double.parse(maxVelocity.toStringAsFixed(1)),
      'averageDeltaMs': double.parse(averageDeltaMs.toStringAsFixed(2)),
      'estimatedProcessingLatencyMs': double.parse(estimatedProcessingLatencyMs.toStringAsFixed(2)),
      'smoothingAmount': double.parse(smoothingAmount.toStringAsFixed(3)),
      if (cornerDeviationPx != null)
        'cornerDeviationPx': double.parse(cornerDeviationPx!.toStringAsFixed(2)),
      'averageDeviationPx': double.parse(averageDeviationPx.toStringAsFixed(2)),
      'maxDeviationPx': double.parse(maxDeviationPx.toStringAsFixed(2)),
      'predictionDistancePx': double.parse(predictionDistancePx.toStringAsFixed(2)),
      'prediction': prediction,
      'config': config.toJson(),
      if (geometry != null) 'geometry': geometry!.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Deserializes a [StrokeBenchmarkReport] from a JSON map.
  factory StrokeBenchmarkReport.fromJson(Map<String, dynamic> json) {
    return StrokeBenchmarkReport(
      platform: json['platform'] as String? ?? 'unknown',
      androidVersion: json['androidVersion'] as String?,
      device: json['device'] as String? ?? 'Unknown',
      cpuArchitecture: json['cpuArchitecture'] as String?,
      refreshRate: (json['refreshRate'] as num?)?.toDouble(),
      devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 1.0,
      screenResolution: json['screenResolution'] as String? ?? 'unknown',
      test: json['test'] as String? ?? 'unknown',
      rawPoints: json['rawPoints'] as int? ?? 0,
      processedPoints: json['processedPoints'] as int? ?? 0,
      averageVelocity: (json['averageVelocity'] as num?)?.toDouble() ?? 0.0,
      maxVelocity: (json['maxVelocity'] as num?)?.toDouble() ?? 0.0,
      averageDeltaMs: (json['averageDeltaMs'] as num?)?.toDouble() ?? 0.0,
      estimatedProcessingLatencyMs: (json['estimatedProcessingLatencyMs'] as num?)?.toDouble() ??
          (json['latencyEstimateMs'] as num?)?.toDouble() ??
          0.0,
      smoothingAmount: (json['smoothingAmount'] as num?)?.toDouble() ?? 0.0,
      cornerDeviationPx: (json['cornerDeviationPx'] as num?)?.toDouble(),
      averageDeviationPx: (json['averageDeviationPx'] as num?)?.toDouble() ?? 0.0,
      maxDeviationPx: (json['maxDeviationPx'] as num?)?.toDouble() ?? 0.0,
      predictionDistancePx: (json['predictionDistancePx'] as num?)?.toDouble() ?? 0.0,
      prediction: json['prediction'] as bool? ?? false,
      config: json['config'] != null
          ? StabilizerConfig.fromJson(json['config'] as Map<String, dynamic>)
          : const StabilizerConfig(),
      geometry: json['geometry'] != null
          ? StrokeGeometryReport.fromJson(json['geometry'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now().toUtc(),
    );
  }

  /// Returns a pretty-printed, indented JSON representation.
  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  @override
  String toString() => toPrettyJson();
}

/// Accumulator collecting raw digitizer and kinematics statistics during a single stroke.
class StrokeBenchmarkCollector {
  final List<Offset> _rawPositions = [];
  final List<Duration> _rawTimestamps = [];
  final List<double> _velocities = [];
  final List<double> _deltaMsList = [];
  final List<double> _streamlineFactors = [];
  final List<double> _cornerDeviations = [];
  final List<double> _predictionDistances = [];

  double _maxVelocity = 0.0;

  void reset() {
    _rawPositions.clear();
    _rawTimestamps.clear();
    _velocities.clear();
    _deltaMsList.clear();
    _streamlineFactors.clear();
    _cornerDeviations.clear();
    _predictionDistances.clear();
    _maxVelocity = 0.0;
  }

  /// Records an incoming raw hardware sample.
  void recordRawSample(Offset position, Duration timestamp) {
    if (_rawTimestamps.isNotEmpty) {
      final dtMs = (timestamp - _rawTimestamps.last).inMicroseconds / 1000.0;
      if (dtMs > 0.0 && dtMs < 200.0) {
        _deltaMsList.add(dtMs);
      }
    }
    _rawPositions.add(position);
    _rawTimestamps.add(timestamp);
  }

  /// Records instantaneous smoothed velocity and applied streamline factor.
  void recordKinematics({required double velocity, required double streamline}) {
    _velocities.add(velocity);
    _streamlineFactors.add(streamline);
    if (velocity > _maxVelocity) {
      _maxVelocity = velocity;
    }
  }

  /// Records deviation between a raw corner apex and the smoothed curve position.
  void recordCornerApexDeviation(Offset rawApex, Offset smoothedPos) {
    final dev = (rawApex - smoothedPos).distance;
    _cornerDeviations.add(dev);
  }

  /// Records distance extrapolated by the forward predictor.
  void recordPredictionDistance(double distance) {
    _predictionDistances.add(distance);
  }

  /// Synthesizes a finalized [StrokeBenchmarkReport].
  StrokeBenchmarkReport finalizeReport({
    required String testMode,
    List<Offset> processedPositions = const [],
    int? processedPointsCount,
    required StabilizerConfig config,
    String platform = 'unknown',
    String? androidVersion,
    String device = 'Unknown',
    String? cpuArchitecture,
    double? refreshRate,
    double devicePixelRatio = 1.0,
    String screenResolution = 'unknown',
  }) {
    final rawCount = _rawPositions.length;
    final processedCount = processedPositions.isNotEmpty
        ? processedPositions.length
        : (processedPointsCount ?? 0);

    // Average delta time
    final avgDeltaMs = _deltaMsList.isNotEmpty
        ? _deltaMsList.reduce((a, b) => a + b) / _deltaMsList.length
        : (refreshRate != null && refreshRate > 0 ? 1000.0 / refreshRate : 16.67);

    // Velocities
    final avgVelocity = _velocities.isNotEmpty
        ? _velocities.reduce((a, b) => a + b) / _velocities.length
        : 0.0;

    // Streamline / Smoothing factor
    final avgSmoothing = _streamlineFactors.isNotEmpty
        ? _streamlineFactors.reduce((a, b) => a + b) / _streamlineFactors.length
        : config.streamlineSlow;

    // Estimated processing delay (ms):
    // 1. Digitizer sample period: avgDeltaMs
    // 2. Exponential smoothing group delay: avgDeltaMs * (avgSmoothing / (1 - avgSmoothing))
    // 3. Subtracted by prediction horizon if active
    final filterDelayMs = avgSmoothing < 0.98
        ? avgDeltaMs * (avgSmoothing / math.max(0.02, 1.0 - avgSmoothing))
        : avgDeltaMs * 5.0;
    final predHorizon = config.predictionEnabled ? config.predictionHorizonMs : 0.0;
    final latencyEstimate = math.max(0.0, avgDeltaMs + filterDelayMs - predHorizon);

    // Comprehensive geometric deviation analysis:
    // Compares raw hardware path against processed/stabilized stroke
    final geometry = StrokeGeometryAnalyzer.analyze(
      _rawPositions,
      processedPositions,
      testMode: testMode,
    );

    // If a genuine corner was detected, report its measured apex deviation.
    // If no corner was detected, report null rather than fabricating 0.0.
    final double? finalCornerDev = geometry.corner.detected
        ? geometry.corner.apexDeviationPx
        : (_cornerDeviations.isNotEmpty ? _cornerDeviations.reduce(math.max) : null);

    // Max prediction distance (px)
    final maxPredDist = _predictionDistances.isNotEmpty
        ? _predictionDistances.reduce(math.max)
        : 0.0;

    return StrokeBenchmarkReport(
      platform: platform,
      androidVersion: androidVersion,
      device: device,
      cpuArchitecture: cpuArchitecture,
      refreshRate: refreshRate,
      devicePixelRatio: devicePixelRatio,
      screenResolution: screenResolution,
      test: testMode,
      rawPoints: rawCount,
      processedPoints: processedCount,
      averageVelocity: avgVelocity,
      maxVelocity: _maxVelocity,
      averageDeltaMs: avgDeltaMs,
      estimatedProcessingLatencyMs: latencyEstimate,
      smoothingAmount: avgSmoothing,
      cornerDeviationPx: finalCornerDev,
      averageDeviationPx: geometry.averageDeviationPx,
      maxDeviationPx: geometry.maxDeviationPx,
      geometry: geometry,
      predictionDistancePx: maxPredDist,
      prediction: config.predictionEnabled,
      config: config,
      timestamp: DateTime.now().toUtc(),
    );
  }
}
