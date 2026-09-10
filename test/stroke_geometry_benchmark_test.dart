import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('Stroke Geometry Engine Benchmark (100, 1000, 10000 points)', () {
    List<StrokePoint> generateCenterline(int count) {
      final points = <StrokePoint>[];
      for (int i = 0; i < count; i++) {
        final t = i * 0.05;
        // Natural handwriting / scribble curve with bends and turns
        final x = 200 + 150 * math.cos(t) + 30 * math.sin(t * 3.5);
        final y = 300 + 150 * math.sin(t) + 30 * math.cos(t * 2.1);
        final pressure = 0.5 + 0.4 * math.sin(t * 1.5);
        final velocity = 300 + 200 * math.cos(t * 2.0);

        points.add(StrokePoint(
          position: Offset(x, y),
          timestamp: Duration(milliseconds: i * 8),
          pressure: pressure,
          velocity: velocity,
        ));
      }
      return points;
    }

    test('Benchmark: 100 points geometry generation', () {
      final points = generateCenterline(100);
      const builder = StrokeGeometryBuilder(
        widthProfile: DynamicWidthProfile(StrokeWidthConfig(
          baseWidth: 12.0,
          pressureEnabled: true,
          velocityEnabled: true,
        )),
        cap: StrokeCapType.round,
        join: StrokeJoinType.round,
      );

      // Warmup
      builder.buildFromPoints(points);

      final stopwatch = Stopwatch()..start();
      const iterations = 50;
      StrokeOutline? lastOutline;
      for (int i = 0; i < iterations; i++) {
        lastOutline = builder.buildFromPoints(points);
      }
      stopwatch.stop();

      final avgMs = stopwatch.elapsedMicroseconds / (iterations * 1000.0);
      // ignore: avoid_print
      print('--- 100 Points Geometry Benchmark ---');
      // ignore: avoid_print
      print('Avg Generation Time: ${avgMs.toStringAsFixed(3)} ms');
      // ignore: avoid_print
      print('Contour Point Count: ${lastOutline!.contour.length}');
      // ignore: avoid_print
      print('Centerline Length:   ${lastOutline.centerlineLength.toStringAsFixed(1)} px');
      // ignore: avoid_print
      print('Outline Perimeter:   ${lastOutline.perimeter.toStringAsFixed(1)} px');

      expect(avgMs, lessThan(50.0)); // Well under 50ms under heavy test runner load
      expect(lastOutline.contour.length, greaterThan(100));
    });

    test('Benchmark: 1,000 points geometry generation', () {
      final points = generateCenterline(1000);
      const builder = StrokeGeometryBuilder(
        widthProfile: DynamicWidthProfile(StrokeWidthConfig(
          baseWidth: 12.0,
          pressureEnabled: true,
          velocityEnabled: true,
        )),
        cap: StrokeCapType.round,
        join: StrokeJoinType.round,
      );

      // Warmup
      builder.buildFromPoints(points);

      final stopwatch = Stopwatch()..start();
      const iterations = 20;
      StrokeOutline? lastOutline;
      for (int i = 0; i < iterations; i++) {
        lastOutline = builder.buildFromPoints(points);
      }
      stopwatch.stop();

      final avgMs = stopwatch.elapsedMicroseconds / (iterations * 1000.0);
      // ignore: avoid_print
      print('--- 1,000 Points Geometry Benchmark ---');
      // ignore: avoid_print
      print('Avg Generation Time: ${avgMs.toStringAsFixed(3)} ms');
      // ignore: avoid_print
      print('Contour Point Count: ${lastOutline!.contour.length}');
      // ignore: avoid_print
      print('Centerline Length:   ${lastOutline.centerlineLength.toStringAsFixed(1)} px');
      // ignore: avoid_print
      print('Outline Perimeter:   ${lastOutline.perimeter.toStringAsFixed(1)} px');

      expect(avgMs, lessThan(100.0)); // Well under 100ms under heavy test runner load
      expect(lastOutline.contour.length, greaterThan(1000));
    });

    test('Benchmark: 10,000 points geometry generation', () {
      final points = generateCenterline(10000);
      const builder = StrokeGeometryBuilder(
        widthProfile: DynamicWidthProfile(StrokeWidthConfig(
          baseWidth: 12.0,
          pressureEnabled: true,
          velocityEnabled: true,
        )),
        cap: StrokeCapType.round,
        join: StrokeJoinType.round,
      );

      // Warmup
      builder.buildFromPoints(points);

      final stopwatch = Stopwatch()..start();
      const iterations = 5;
      StrokeOutline? lastOutline;
      for (int i = 0; i < iterations; i++) {
        lastOutline = builder.buildFromPoints(points);
      }
      stopwatch.stop();

      final avgMs = stopwatch.elapsedMicroseconds / (iterations * 1000.0);
      // ignore: avoid_print
      print('--- 10,000 Points Geometry Benchmark ---');
      // ignore: avoid_print
      print('Avg Generation Time: ${avgMs.toStringAsFixed(3)} ms');
      // ignore: avoid_print
      print('Contour Point Count: ${lastOutline!.contour.length}');
      // ignore: avoid_print
      print('Centerline Length:   ${lastOutline.centerlineLength.toStringAsFixed(1)} px');
      // ignore: avoid_print
      print('Outline Perimeter:   ${lastOutline.perimeter.toStringAsFixed(1)} px');

      expect(avgMs, lessThan(350.0)); // Linear O(N) scaling under test runner load
      expect(lastOutline.contour.length, greaterThan(10000));
    });
  });
}
