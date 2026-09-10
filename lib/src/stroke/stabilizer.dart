import '../input/pointer_sample.dart';
import '../processor/benchmark_report.dart';
import '../processor/input_processor.dart';
import '../processor/pressure_source.dart';
import '../processor/stabilizer_config.dart';
import '../processor/stroke_diagnostics.dart';
import 'stroke_point.dart';

/// Real-time stroke stabilizer delegating to modular [InputProcessor] components.
///
/// Provides backwards compatibility with v0.1 while unlocking v0.2 advanced
/// stabilization, velocity-calibrated smoothing, and corner preservation.
class Stabilizer {
  final InputProcessor _processor;

  Stabilizer({
    double minDistance = 1.5,
    double streamline = 0.25,
    double maxSpeed = 2000.0,
    StabilizerConfig? config,
    PressureSource? pressureSource,
  }) : _processor = InputProcessor(
          config: config ??
              StabilizerConfig(
                minDistance: minDistance,
                streamlineSlow: streamline,
                streamlineFast: streamline * 0.35,
                velocityMax: maxSpeed,
              ),
          pressureSource: pressureSource,
        );

  Stabilizer.withProcessor(InputProcessor processor) : _processor = processor;

  StabilizerConfig get config => _processor.config;
  List<StrokePoint> get smoothedPoints => _processor.processedPoints;

  void reset() => _processor.reset();

  /// Adds a sample and returns new smoothed points.
  List<StrokePoint> addSample(PointerSample sample, {double baseWidth = 4.0}) {
    return _processor.processSample(sample, baseWidth: baseWidth);
  }

  /// Evaluates optional transient tip prediction.
  StrokePoint? predictTip({required double baseWidth}) {
    return _processor.predictTip(baseWidth: baseWidth);
  }

  /// Returns real-time stroke diagnostics telemetry.
  StrokeDiagnostics getDiagnostics({int activePointerCount = 1}) {
    return _processor.getDiagnostics(activePointerCount: activePointerCount);
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
    return _processor.finalizeBenchmarkReport(
      testMode: testMode,
      platform: platform,
      androidVersion: androidVersion,
      device: device,
      cpuArchitecture: cpuArchitecture,
      refreshRate: refreshRate,
      devicePixelRatio: devicePixelRatio,
      screenResolution: screenResolution,
    );
  }
}
