import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('StrokeBenchmarkReport & Collector Tests', () {
    test('StrokeBenchmarkReport serializes to JSON matching required schema', () {
      const config = StabilizerConfig(
        streamlineSlow: 0.45,
        streamlineFast: 0.08,
      );

      final report = StrokeBenchmarkReport(
        platform: 'android',
        androidVersion: '14 (SDK 34)',
        device: 'Google Pixel 8',
        cpuArchitecture: 'arm64-v8a',
        refreshRate: 120.0,
        devicePixelRatio: 3.0,
        screenResolution: '1080x2400 physical (360x800 logical)',
        test: 'fast_scribble',
        rawPoints: 124,
        processedPoints: 120,
        averageVelocity: 812.4,
        maxVelocity: 1250.0,
        averageDeltaMs: 8.33,
        estimatedProcessingLatencyMs: 14.5,
        smoothingAmount: 0.125,
        cornerDeviationPx: 2.1,
        averageDeviationPx: 0.45,
        maxDeviationPx: 2.1,
        predictionDistancePx: 0.0,
        prediction: false,
        config: config,
        timestamp: DateTime.utc(2026, 9, 9, 1, 0, 0),
      );

      final jsonMap = report.toJson();
      expect(jsonMap['platform'], 'android');
      expect(jsonMap['androidVersion'], '14 (SDK 34)');
      expect(jsonMap['device'], 'Google Pixel 8');
      expect(jsonMap['cpuArchitecture'], 'arm64-v8a');
      expect(jsonMap['refreshRate'], 120);
      expect(jsonMap['devicePixelRatio'], 3.0);
      expect(jsonMap['screenResolution'], contains('1080x2400'));
      expect(jsonMap['test'], 'fast_scribble');
      expect(jsonMap['rawPoints'], 124);
      expect(jsonMap['processedPoints'], 120);
      expect(jsonMap['averageVelocity'], 812.4);
      expect(jsonMap['maxVelocity'], 1250.0);
      expect(jsonMap['averageDeltaMs'], 8.33);
      expect(jsonMap['estimatedProcessingLatencyMs'], 14.5);
      expect(jsonMap['cornerDeviationPx'], 2.1);
      expect(jsonMap['averageDeviationPx'], 0.45);
      expect(jsonMap['maxDeviationPx'], 2.1);
      expect(jsonMap['prediction'], false);
      expect(jsonMap['config'], isA<Map<String, dynamic>>());

      final prettyJson = report.toPrettyJson();
      final decoded = jsonDecode(prettyJson) as Map<String, dynamic>;
      expect(decoded['platform'], 'android');
      expect(decoded['test'], 'fast_scribble');
      expect(decoded['refreshRate'], 120);

      final deserialized = StrokeBenchmarkReport.fromJson(decoded);
      expect(deserialized.platform, 'android');
      expect(deserialized.cornerDeviationPx, 2.1);
      expect(deserialized.averageDeviationPx, 0.45);
      expect(deserialized.maxDeviationPx, 2.1);
    });

    test('StabilizerConfig serializes to and from JSON', () {
      const original = StabilizerConfig(
        minDistance: 2.0,
        velocityMin: 150.0,
        velocityMax: 900.0,
        streamlineSlow: 0.50,
        streamlineFast: 0.10,
        cornerAngleDeg: 70.0,
        cornerSmoothingFactor: 0.15,
        predictionEnabled: true,
        predictionHorizonMs: 14.0,
        maxPredictionDistance: 18.0,
      );

      final json = original.toJson();
      final restored = StabilizerConfig.fromJson(json);

      expect(restored.minDistance, 2.0);
      expect(restored.velocityMin, 150.0);
      expect(restored.velocityMax, 900.0);
      expect(restored.streamlineSlow, 0.50);
      expect(restored.streamlineFast, 0.10);
      expect(restored.cornerAngleDeg, 70.0);
      expect(restored.cornerSmoothingFactor, 0.15);
      expect(restored.predictionEnabled, isTrue);
      expect(restored.predictionHorizonMs, 14.0);
      expect(restored.maxPredictionDistance, 18.0);
    });

    test('KidzCanvasController records benchmark report upon stroke completion', () {
      final controller = KidzCanvasController();
      controller.setBenchmarkContext(
        testMode: 'sharp_corners',
        device: 'Test Phone',
        refreshRate: 90.0,
      );

      const t0 = Duration.zero;
      const t1 = Duration(milliseconds: 10);
      const t2 = Duration(milliseconds: 20);
      const t3 = Duration(milliseconds: 30);

      // Draw a stroke with a sharp corner: (0,0) -> (50, 0) -> (50, 50)
      controller.handlePointerDown(const PointerSample(
        pointerId: 1,
        position: Offset(0, 0),
        timestamp: t0,
      ));

      controller.handlePointerMove(const PointerSample(
        pointerId: 1,
        position: Offset(25, 0),
        timestamp: t1,
      ));

      controller.handlePointerMove(const PointerSample(
        pointerId: 1,
        position: Offset(50, 0),
        timestamp: t2,
      ));

      // Sharp 90° turn
      controller.handlePointerMove(const PointerSample(
        pointerId: 1,
        position: Offset(50, 40),
        timestamp: t3,
      ));

      controller.handlePointerUp(const PointerSample(
        pointerId: 1,
        position: Offset(50, 40),
        timestamp: t3,
      ));

      final report = controller.lastBenchmarkReport;
      expect(report, isNotNull);
      expect(report!.test, 'sharp_corners');
      expect(report.device, 'Test Phone');
      expect(report.refreshRate, 90.0);
      expect(report.rawPoints, greaterThanOrEqualTo(4));
      expect(report.processedPoints, greaterThan(0));
      expect(report.averageDeltaMs, greaterThan(0));
      expect(report.averageVelocity, greaterThan(0));
      expect(report.maxVelocity, greaterThan(0));
      expect(controller.benchmarkHistory.length, 1);

      // Verify clear
      controller.clearBenchmarkHistory();
      expect(controller.benchmarkHistory, isEmpty);
    });

    test('Geometric deviation diagnostic correctly measures corner apex and path deviation', () {
      final controller = KidzCanvasController();
      controller.setBenchmarkContext(
        testMode: 'sharp_corners',
        device: 'Realme RMX3785',
        refreshRate: 120.0,
      );

      // Simulate a multi-sample 90-degree corner at 120Hz (points arriving every 8ms):
      // Approaching corner along X: (0,0), (15,0), (30,0), (45,0), (60,0) [vertex]
      // Turning down along Y: (60,15), (60,30), (60,45), (60,60)
      final cornerPoints = [
        const Offset(0, 0),
        const Offset(15, 0),
        const Offset(30, 0),
        const Offset(45, 0),
        const Offset(60, 0), // Apex at 60,0
        const Offset(60, 15),
        const Offset(60, 30),
        const Offset(60, 45),
        const Offset(60, 60),
      ];

      for (int i = 0; i < cornerPoints.length; i++) {
        final sample = PointerSample(
          pointerId: 1,
          position: cornerPoints[i],
          timestamp: Duration(milliseconds: i * 8),
        );
        if (i == 0) {
          controller.handlePointerDown(sample);
        } else if (i == cornerPoints.length - 1) {
          controller.handlePointerUp(sample);
        } else {
          controller.handlePointerMove(sample);
        }
      }

      final report = controller.lastBenchmarkReport;
      expect(report, isNotNull);
      // Verify corner apex deviation is detected and non-zero
      expect(report!.cornerDeviationPx, greaterThan(0.0));
      expect(report.averageDeviationPx, greaterThan(0.0));
      expect(report.maxDeviationPx, greaterThanOrEqualTo(report.averageDeviationPx));
    });

    test('Straight line stroke reports zero corner deviation but records path metrics', () {
      final controller = KidzCanvasController();
      controller.setBenchmarkContext(
        testMode: 'long_straight_line',
        device: 'Realme RMX3785',
        refreshRate: 120.0,
      );

      // Straight line with 10 samples along X axis
      for (int i = 0; i < 10; i++) {
        final sample = PointerSample(
          pointerId: 1,
          position: Offset(i * 20.0, 50.0),
          timestamp: Duration(milliseconds: i * 8),
        );
        if (i == 0) {
          controller.handlePointerDown(sample);
        } else if (i == 9) {
          controller.handlePointerUp(sample);
        } else {
          controller.handlePointerMove(sample);
        }
      }

      final report = controller.lastBenchmarkReport;
      expect(report, isNotNull);
      // No corners in straight line
      expect(report!.cornerDeviationPx, isNull);
      expect(report.averageDeviationPx, greaterThanOrEqualTo(0.0));
      expect(report.maxDeviationPx, greaterThanOrEqualTo(0.0));
    });
  });
}
