import 'dart:ui';
import 'package:flutter/gestures.dart';
import '../input/pointer_sample.dart';
import '../stroke/catmull_rom.dart';
import '../stroke/stroke_point.dart';
import 'adaptive_smoother.dart';
import 'benchmark_report.dart';
import 'corner_preserver.dart';
import 'kinematics.dart';
import 'noise_filter.dart';
import 'predictor.dart';
import 'pressure_source.dart';
import 'stabilizer_config.dart';
import 'stroke_diagnostics.dart';

/// Modular input processor orchestrating noise filtering, kinematics,
/// adaptive smoothing, corner preservation, and optional prediction.
class InputProcessor {
  final StabilizerConfig config;
  final NoiseFilter noiseFilter;
  final KinematicsTracker kinematics;
  final PressureSource pressureSource;
  final AdaptiveSmoother adaptiveSmoother;
  final CornerPreserver cornerPreserver;
  final Predictor predictor;
  final StrokeBenchmarkCollector _benchmarkCollector = StrokeBenchmarkCollector();

  final List<PointerSample> _rawSamples = [];
  final List<StrokePoint> _processedPoints = [];
  final List<Offset> _rawHardwarePoints = [];
  final List<Offset> _catmullPoints = [];

  Offset? _lastPredictedTip;
  double _lastPressure = 1.0;
  PointerDeviceKind _lastDeviceKind = PointerDeviceKind.touch;
  StrokeBenchmarkReport? _lastReport;

  InputProcessor({
    StabilizerConfig? config,
    NoiseFilter? noiseFilter,
    KinematicsTracker? kinematics,
    PressureSource? pressureSource,
  })  : config = config ?? const StabilizerConfig(),
        noiseFilter = noiseFilter ?? NoiseFilter(minDistance: config?.minDistance ?? 1.5),
        kinematics = kinematics ?? KinematicsTracker(),
        pressureSource = pressureSource ?? const AdaptivePressureSource(),
        adaptiveSmoother = AdaptiveSmoother(config: config ?? const StabilizerConfig()),
        cornerPreserver = CornerPreserver(config: config ?? const StabilizerConfig()),
        predictor = Predictor(config: config ?? const StabilizerConfig());

  List<StrokePoint> get processedPoints => List.unmodifiable(_processedPoints);

  void reset() {
    _rawSamples.clear();
    _processedPoints.clear();
    _rawHardwarePoints.clear();
    _catmullPoints.clear();
    _lastPredictedTip = null;
    kinematics.reset();
    adaptiveSmoother.reset();
    cornerPreserver.reset();
    _benchmarkCollector.reset();
  }

  /// Processes an incoming [PointerSample] and returns newly produced [StrokePoint]s.
  List<StrokePoint> processSample(PointerSample sample, {double baseWidth = 4.0}) {
    _rawHardwarePoints.add(sample.position);
    _lastDeviceKind = sample.deviceType;
    _benchmarkCollector.recordRawSample(sample.position, sample.timestamp);

    // 1. Noise gate
    Offset? lastPos = _rawSamples.isNotEmpty ? _rawSamples.last.position : null;
    if (!noiseFilter.accept(sample, lastPos)) {
      return [];
    }

    // 2. Kinematics & Velocity
    if (_rawSamples.isNotEmpty) {
      kinematics.update(sample, _rawSamples.last);
    }

    // 3. Corner detection: check if sharp direction change should reduce smoothing
    final cornerOverride = cornerPreserver.checkDirectionChange(sample.position);

    // 4. Adaptive low-pass streamline smoothing
    final smoothedPos = adaptiveSmoother.smooth(
      sample.position,
      kinematics.smoothedVelocity,
      overrideFactor: cornerOverride,
    );

    // Benchmark statistics recording
    final effectiveStreamline = cornerOverride ??
        adaptiveSmoother.computeStreamlineFactor(kinematics.smoothedVelocity);
    _benchmarkCollector.recordKinematics(
      velocity: kinematics.smoothedVelocity,
      streamline: effectiveStreamline,
    );
    if (cornerOverride != null) {
      _benchmarkCollector.recordCornerApexDeviation(sample.position, smoothedPos);
    }

    // 5. Pressure resolution
    final pressure = pressureSource.resolve(
      sample,
      velocity: kinematics.smoothedVelocity,
      maxVelocity: kinematics.maxVelocity,
    );
    _lastPressure = pressure;

    final filteredSample = sample.copyWith(position: smoothedPos);
    _rawSamples.add(filteredSample);
    final n = _rawSamples.length;

    // 6. Curve generation & point aggregation
    if (n == 1) {
      final p0 = StrokePoint(
        position: smoothedPos,
        timestamp: sample.timestamp,
        pressure: pressure,
        tilt: sample.tilt,
        orientation: sample.orientation,
        width: baseWidth,
        velocity: 0.0,
      );
      _processedPoints.add(p0);
      return [p0];
    }

    if (n == 2) {
      final pPrev = _rawSamples[0].position;
      final mid = Offset((pPrev.dx + smoothedPos.dx) * 0.5, (pPrev.dy + smoothedPos.dy) * 0.5);

      final pMid = StrokePoint(
        position: mid,
        timestamp: sample.timestamp,
        pressure: pressure,
        tilt: sample.tilt,
        orientation: sample.orientation,
        width: baseWidth,
        velocity: kinematics.smoothedVelocity,
      );
      _processedPoints.add(pMid);
      return [pMid];
    }

    final newPoints = <StrokePoint>[];
    final lastSmoothedPos = _rawSamples[n - 2].position;
    final dist = (smoothedPos - lastSmoothedPos).distance;

    // Catmull-Rom interpolation for rapid movements
    if (dist > config.catmullThreshold && n >= 4 && cornerOverride == null) {
      final p0 = _rawSamples[n - 4].position;
      final p1 = _rawSamples[n - 3].position;
      final p2 = _rawSamples[n - 2].position;
      final p3 = smoothedPos;

      final interpolated = CatmullRomSpline.interpolateSegment(
        p0: p0,
        p1: p1,
        p2: p2,
        p3: p3,
        steps: config.catmullSteps,
      );

      for (final interpPos in interpolated) {
        _catmullPoints.add(interpPos);
        final pt = StrokePoint(
          position: interpPos,
          timestamp: sample.timestamp,
          pressure: pressure,
          tilt: sample.tilt,
          orientation: sample.orientation,
          width: baseWidth,
          velocity: kinematics.smoothedVelocity,
        );
        _processedPoints.add(pt);
        newPoints.add(pt);
      }
    }

    // Midpoint smoothing
    final pPrev = _rawSamples[n - 2].position;
    final mid = Offset((pPrev.dx + smoothedPos.dx) * 0.5, (pPrev.dy + smoothedPos.dy) * 0.5);

    final midPoint = StrokePoint(
      position: mid,
      timestamp: sample.timestamp,
      pressure: pressure,
      tilt: sample.tilt,
      orientation: sample.orientation,
      width: baseWidth,
      velocity: kinematics.smoothedVelocity,
    );

    _processedPoints.add(midPoint);
    newPoints.add(midPoint);

    return newPoints;
  }

  /// Evaluates optional 1-frame forward prediction for the leading active tip.
  StrokePoint? predictTip({required double baseWidth}) {
    if (!config.predictionEnabled || _processedPoints.isEmpty) {
      _lastPredictedTip = null;
      return null;
    }

    final lastPt = _processedPoints.last;
    final tip = predictor.predictTip(
      position: lastPt.position,
      direction: kinematics.lastDirection,
      velocity: kinematics.smoothedVelocity,
      width: baseWidth,
      pressure: lastPt.pressure,
      timestamp: lastPt.timestamp,
    );
    _lastPredictedTip = tip?.position;
    if (tip != null) {
      final dist = (tip.position - lastPt.position).distance;
      _benchmarkCollector.recordPredictionDistance(dist);
    }
    return tip;
  }

  /// Finalizes and returns a quantitative [StrokeBenchmarkReport] for the completed stroke.
  StrokeBenchmarkReport finalizeBenchmarkReport({
    required String testMode,
    String platform = 'unknown',
    String? androidVersion,
    String device = 'Unknown',
    String? cpuArchitecture,
    double? refreshRate,
    double devicePixelRatio = 1.0,
    String screenResolution = 'unknown',
  }) {
    final rep = _benchmarkCollector.finalizeReport(
      testMode: testMode,
      processedPositions: _processedPoints.map((p) => p.position).toList(growable: false),
      config: config,
      platform: platform,
      androidVersion: androidVersion,
      device: device,
      cpuArchitecture: cpuArchitecture,
      refreshRate: refreshRate,
      devicePixelRatio: devicePixelRatio,
      screenResolution: screenResolution,
    );
    _lastReport = rep;
    return rep;
  }

  /// Generates a real-time diagnostics snapshot for telemetry HUD and visual debug overlays.
  StrokeDiagnostics getDiagnostics({int activePointerCount = 1}) {
    return StrokeDiagnostics(
      rawPoints: List.unmodifiable(_rawHardwarePoints),
      stabilizedPoints: _processedPoints.map((p) => p.position).toList(growable: false),
      catmullPoints: List.unmodifiable(_catmullPoints),
      predictedTip: _lastPredictedTip,
      currentVelocity: kinematics.smoothedVelocity,
      currentPressure: _lastPressure,
      deviceKind: _lastDeviceKind,
      activePointerCount: activePointerCount,
      rawApex: _lastReport?.geometry?.corner.rawApex,
      processedApex: _lastReport?.geometry?.corner.processedApex,
    );
  }
}
