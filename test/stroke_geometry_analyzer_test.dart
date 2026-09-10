import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('StrokeGeometryAnalyzer Tests', () {
    // 1. identical raw/processed paths -> deviation = 0
    test('1. identical raw/processed paths produce exactly zero deviation', () {
      final points = [
        const Offset(10, 10),
        const Offset(20, 20),
        const Offset(30, 25),
        const Offset(40, 30),
        const Offset(50, 35),
      ];

      final report = StrokeGeometryAnalyzer.analyze(points, points);

      expect(report.maxDeviationPx, 0.0);
      expect(report.averageDeviationPx, 0.0);
      expect(report.rmsDeviationPx, 0.0);
      expect(report.maxDisplacementPx, 0.0);
      expect(report.rawPathLength, equals(report.processedPathLength));
      expect(report.rawBounds, equals(report.processedBounds));
    });

    // 2. translated processed path -> correct displacement
    test('2. translated processed path produces exact displacement measurement',
        () {
      final rawPoints = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(40, 0),
        const Offset(60, 0),
      ];
      // Translated 10px in X direction
      final processedPoints = [
        const Offset(0, 10),
        const Offset(20, 10),
        const Offset(40, 10),
        const Offset(60, 10),
      ];

      final report = StrokeGeometryAnalyzer.analyze(rawPoints, processedPoints);

      // Every raw point is exactly 10.0 px away from the parallel segment
      expect(report.maxDeviationPx, closeTo(10.0, 0.01));
      expect(report.averageDeviationPx, closeTo(10.0, 0.01));
      expect(report.rmsDeviationPx, closeTo(10.0, 0.01));
      expect(report.maxDisplacementPx, closeTo(10.0, 0.01));
    });

    // 3. known corner -> correct apex deviation
    test('3. known corner produces correct apex position and deviation', () {
      // 90-degree corner with apex at (50, 50)
      final rawPoints = [
        const Offset(10, 50),
        const Offset(25, 50),
        const Offset(40, 50),
        const Offset(50, 50), // apex
        const Offset(50, 65),
        const Offset(50, 80),
        const Offset(50, 100),
      ];

      // Smoothed path that rounds the corner by passing through (48, 52)
      final processedPoints = [
        const Offset(10, 50),
        const Offset(35, 50),
        const Offset(45, 55), // rounded off inside
        const Offset(50, 65),
        const Offset(50, 100),
      ];

      final report = StrokeGeometryAnalyzer.analyze(rawPoints, processedPoints);

      expect(report.corner.detected, isTrue);
      expect(report.corner.rawApex, equals(const Offset(50, 50)));
      expect(report.corner.apexDeviationPx, isNotNull);
      expect(report.corner.apexDeviationPx!, greaterThan(0.0));
      expect(report.corner.incomingDirection, isNotNull);
      expect(report.corner.outgoingDirection, isNotNull);
      expect(report.corner.detectedAngleDeg, isNotNull);
      expect(report.corner.detectedAngleDeg!, closeTo(90.0, 5.0));
    });

    // 4. straight line -> expected line deviation
    test('4. straight line produces expected linear regression metrics', () {
      // Line with slight wobble of 1px at one point: y = 20 except at x=30 where y=21
      final rawPoints = [
        const Offset(0, 20),
        const Offset(15, 20),
        const Offset(30, 21), // 1px wobble
        const Offset(45, 20),
        const Offset(60, 20),
      ];

      final processedPoints = [
        const Offset(0, 20),
        const Offset(30, 20),
        const Offset(60, 20),
      ];

      final report = StrokeGeometryAnalyzer.analyze(rawPoints, processedPoints);

      expect(report.straightLine, isNotNull);
      expect(report.straightLine!.maxDeviationPx, greaterThan(0.0));
      expect(report.straightLine!.maxDeviationPx, lessThanOrEqualTo(1.0));
      expect(report.straightLine!.averageDeviationPx, greaterThan(0.0));
      expect(report.straightLine!.lineAngleDeg, closeTo(0.0, 5.0));
    });

    // 5. circle -> expected radial error
    test('5. circle produces expected circle center, radius, and radial error',
        () {
      // Circle centered at (100, 100) with radius 50
      const center = Offset(100, 100);
      const r = 50.0;
      final rawPoints = <Offset>[];
      final processedPoints = <Offset>[];

      for (int i = 0; i <= 24; i++) {
        final angle = (i * 2.0 * math.pi) / 24;
        rawPoints.add(Offset(
            center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));
        // Slightly flattened processed circle (radius 48)
        processedPoints.add(Offset(center.dx + 48.0 * math.cos(angle),
            center.dy + 48.0 * math.sin(angle)));
      }

      final report = StrokeGeometryAnalyzer.analyze(rawPoints, processedPoints);

      expect(report.circle, isNotNull);
      expect(report.circle!.fittedCenter.dx, closeTo(100.0, 0.5));
      expect(report.circle!.fittedCenter.dy, closeTo(100.0, 0.5));
      expect(report.circle!.fittedRadius, closeTo(50.0, 0.5));
      expect(report.circle!.radiusVariation, closeTo(0.0, 0.1));
      expect(report.circle!.maxRadialErrorPx, closeTo(0.0, 0.1));
      // Processed circle has ~2px radial error from raw fit
      expect(report.circle!.processedAvgRadialErrorPx, closeTo(2.0, 0.2));
    });

    // 6. no corner -> detected=false, not 0.0
    test(
        '6. smooth curve or straight line reports detected=false and null apex',
        () {
      final linePoints = [
        const Offset(10, 10),
        const Offset(25, 10),
        const Offset(40, 10),
        const Offset(55, 10),
        const Offset(70, 10),
      ];

      final report = StrokeGeometryAnalyzer.analyze(linePoints, linePoints);

      expect(report.corner.detected, isFalse);
      expect(report.corner.rawApex, isNull);
      expect(report.corner.processedApex, isNull);
      expect(report.corner.apexDeviationPx, isNull);
      expect(report.corner.detectedAngleDeg, isNull);
    });

    // 7. different coordinate scale -> normalized correctly
    test('7. scaled coordinates retain proportional geometric metrics', () {
      final rawPoints1 = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(20, 20),
      ];
      final processedPoints1 = [
        const Offset(0, 0),
        const Offset(18, 2),
        const Offset(20, 20),
      ];

      // Scaled by 3x (e.g. physical device pixels vs logical)
      final rawPoints3 = rawPoints1.map((p) => p * 3.0).toList();
      final processedPoints3 = processedPoints1.map((p) => p * 3.0).toList();

      final report1 =
          StrokeGeometryAnalyzer.analyze(rawPoints1, processedPoints1);
      final report3 =
          StrokeGeometryAnalyzer.analyze(rawPoints3, processedPoints3);

      expect(
          report3.maxDeviationPx, closeTo(report1.maxDeviationPx * 3.0, 0.01));
      expect(report3.averageDeviationPx,
          closeTo(report1.averageDeviationPx * 3.0, 0.01));
      expect(report3.rawPathLength, closeTo(report1.rawPathLength * 3.0, 0.01));
    });

    // 8. empty/invalid stroke -> safe null result
    test('8. empty or single-point strokes produce safe non-crashing results',
        () {
      final emptyReport = StrokeGeometryAnalyzer.analyze([], []);

      expect(emptyReport.maxDeviationPx, 0.0);
      expect(emptyReport.averageDeviationPx, 0.0);
      expect(emptyReport.rmsDeviationPx, 0.0);
      expect(emptyReport.corner.detected, isFalse);
      expect(emptyReport.straightLine, isNull);
      expect(emptyReport.circle, isNull);

      final singlePointReport = StrokeGeometryAnalyzer.analyze(
          [const Offset(5, 5)], [const Offset(5, 5)]);
      expect(singlePointReport.maxDeviationPx, 0.0);
      expect(singlePointReport.corner.detected, isFalse);
    });

    // 9. JSON serialization and deserialization
    test('9. StrokeGeometryReport serializes to and from JSON matching schema',
        () {
      final raw = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(40, 0),
        const Offset(40, 30),
      ];
      final processed = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(38, 2),
        const Offset(40, 30),
      ];

      final report = StrokeGeometryAnalyzer.analyze(raw, processed);
      final json = report.toJson();

      expect(json['maxDeviationPx'], isA<num>());
      expect(json['averageDeviationPx'], isA<num>());
      expect(json['rmsDeviationPx'], isA<num>());
      expect(json['rawBounds'], isA<Map<String, dynamic>>());
      expect(json['processedBounds'], isA<Map<String, dynamic>>());
      expect(json['corner'], isA<Map<String, dynamic>>());

      final restored = StrokeGeometryReport.fromJson(json);
      expect(restored.maxDeviationPx, closeTo(report.maxDeviationPx, 0.01));
      expect(restored.averageDeviationPx,
          closeTo(report.averageDeviationPx, 0.01));
      expect(restored.corner.detected, equals(report.corner.detected));
    });
  });
}
