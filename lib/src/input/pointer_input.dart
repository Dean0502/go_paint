import 'package:flutter/material.dart';
import '../stroke/stabilizer.dart';
import '../stroke/stroke.dart';
import '../processor/benchmark_report.dart';
import '../processor/stroke_diagnostics.dart';
import '../processor/stabilizer_config.dart';
import 'multi_touch_policy.dart';
import 'pointer_sample.dart';

/// Manages pointer lifecycles, multi-touch isolation, and active stroke assembly.
class PointerInput {
  Stabilizer _stabilizer;
  final MultiTouchPolicy multiTouchPolicy;

  final Set<int> _activePointers = {};
  int? _drawingPointerId;
  PointerInputState _state = PointerInputState.idle;
  Stroke? _activeStroke;

  String _benchmarkTestMode = 'slow_handwriting';
  String _benchmarkPlatform = 'unknown';
  String? _benchmarkAndroidVersion;
  String _deviceDescription = 'Unknown';
  String? _benchmarkCpuArchitecture;
  double? _benchmarkRefreshRate;
  double _benchmarkDevicePixelRatio = 1.0;
  String _benchmarkScreenResolution = 'unknown';
  StrokeBenchmarkReport? _lastBenchmarkReport;

  PointerInput({
    Stabilizer? stabilizer,
    this.multiTouchPolicy = MultiTouchPolicy.completeCurrentStroke,
  }) : _stabilizer = stabilizer ?? Stabilizer();

  Stabilizer get stabilizer => _stabilizer;

  void updateConfig(StabilizerConfig newConfig) {
    _stabilizer = Stabilizer(config: newConfig);
    reset();
  }

  Stroke? get activeStroke => _activeStroke;
  bool get isDrawing =>
      _state == PointerInputState.drawing && _activeStroke != null;
  PointerInputState get state => _state;
  int get activePointerCount => _activePointers.length;
  StrokeDiagnostics get diagnostics =>
      stabilizer.getDiagnostics(activePointerCount: _activePointers.length);

  /// The quantitative benchmark report from the most recently completed stroke.
  StrokeBenchmarkReport? get lastBenchmarkReport => _lastBenchmarkReport;

  /// Sets device, refresh rate, and benchmark mode for upcoming test strokes.
  void setBenchmarkContext({
    String? testMode,
    String? platform,
    String? androidVersion,
    String? device,
    String? cpuArchitecture,
    double? refreshRate,
    double? devicePixelRatio,
    String? screenResolution,
  }) {
    if (testMode != null) _benchmarkTestMode = testMode;
    if (platform != null) _benchmarkPlatform = platform;
    if (androidVersion != null) _benchmarkAndroidVersion = androidVersion;
    if (device != null) _deviceDescription = device;
    if (cpuArchitecture != null) _benchmarkCpuArchitecture = cpuArchitecture;
    _benchmarkRefreshRate = refreshRate;
    if (devicePixelRatio != null) _benchmarkDevicePixelRatio = devicePixelRatio;
    if (screenResolution != null) _benchmarkScreenResolution = screenResolution;
  }

  /// Handles pointer contact down.
  Stroke? onPointerDown(
    PointerSample sample, {
    Color color = Colors.black,
    double width = 4.0,
  }) {
    _activePointers.add(sample.pointerId);

    // Multi-touch detection
    if (_activePointers.length > 1) {
      if (multiTouchPolicy == MultiTouchPolicy.ignoreSecondaryPointers) {
        // Ignore second finger, continue single-finger drawing
        return null;
      }

      _state = PointerInputState.multitouch;

      if (multiTouchPolicy == MultiTouchPolicy.completeCurrentStroke &&
          _activeStroke != null) {
        // Gracefully finalize and commit existing stroke so far
        final completed = _activeStroke!.copyWith(
          points: stabilizer.smoothedPoints,
          isComplete: true,
        );
        _lastBenchmarkReport = stabilizer.finalizeBenchmarkReport(
          testMode: _benchmarkTestMode,
          platform: _benchmarkPlatform,
          androidVersion: _benchmarkAndroidVersion,
          device: _deviceDescription,
          cpuArchitecture: _benchmarkCpuArchitecture,
          refreshRate: _benchmarkRefreshRate,
          devicePixelRatio: _benchmarkDevicePixelRatio,
          screenResolution: _benchmarkScreenResolution,
        );
        _activeStroke = null;
        _drawingPointerId = null;
        stabilizer.reset();
        return completed;
      } else if (multiTouchPolicy == MultiTouchPolicy.cancelCurrentStroke) {
        // Abort stroke
        _activeStroke = null;
        _drawingPointerId = null;
        stabilizer.reset();
        return null;
      }

      return null;
    }

    // First finger touch: initiate drawing
    _state = PointerInputState.drawing;
    _drawingPointerId = sample.pointerId;
    stabilizer.reset();

    final initialPoints = stabilizer.addSample(sample, baseWidth: width);
    final strokeId = 'stroke_${DateTime.now().microsecondsSinceEpoch}';

    _activeStroke = Stroke(
      id: strokeId,
      points: initialPoints,
      color: color,
      baseWidth: width,
      isComplete: false,
    );

    return _activeStroke;
  }

  /// Handles pointer dragging movement.
  Stroke? onPointerMove(PointerSample sample) {
    if (_state != PointerInputState.drawing ||
        _drawingPointerId != sample.pointerId) {
      return null;
    }

    if (_activeStroke == null) return null;

    final newPoints =
        stabilizer.addSample(sample, baseWidth: _activeStroke!.baseWidth);
    if (newPoints.isEmpty) {
      return _activeStroke;
    }

    final realPoints = stabilizer.smoothedPoints;
    final displayPoints = List.of(realPoints);

    // If prediction is enabled, append a transient predicted point to active render
    final predictedTip =
        stabilizer.predictTip(baseWidth: _activeStroke!.baseWidth);
    if (predictedTip != null) {
      displayPoints.add(predictedTip);
    }

    _activeStroke = _activeStroke!.copyWith(points: displayPoints);
    return _activeStroke;
  }

  /// Handles pointer lift up.
  Stroke? onPointerUp(PointerSample sample) {
    _activePointers.remove(sample.pointerId);

    if (_activePointers.isEmpty) {
      _state = PointerInputState.idle;
    }

    if (_drawingPointerId != sample.pointerId || _activeStroke == null) {
      return null;
    }

    // Finalize stroke using ONLY authentic smoothed points (never predicted points)
    final completed = _activeStroke!.copyWith(
      points: stabilizer.smoothedPoints,
      isComplete: true,
    );

    _lastBenchmarkReport = stabilizer.finalizeBenchmarkReport(
      testMode: _benchmarkTestMode,
      platform: _benchmarkPlatform,
      androidVersion: _benchmarkAndroidVersion,
      device: _deviceDescription,
      cpuArchitecture: _benchmarkCpuArchitecture,
      refreshRate: _benchmarkRefreshRate,
      devicePixelRatio: _benchmarkDevicePixelRatio,
      screenResolution: _benchmarkScreenResolution,
    );

    _activeStroke = null;
    _drawingPointerId = null;
    stabilizer.reset();

    return completed;
  }

  /// Handles pointer cancel.
  void onPointerCancel(PointerSample sample) {
    _activePointers.remove(sample.pointerId);

    if (_activePointers.isEmpty) {
      _state = PointerInputState.idle;
    }

    if (_drawingPointerId == sample.pointerId) {
      _activeStroke = null;
      _drawingPointerId = null;
      stabilizer.reset();
    }
  }

  /// Explicit reset.
  void reset() {
    _activePointers.clear();
    _drawingPointerId = null;
    _state = PointerInputState.idle;
    _activeStroke = null;
    stabilizer.reset();
  }
}
