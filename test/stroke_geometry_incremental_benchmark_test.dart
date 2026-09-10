import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('KIDZ CANVAS v0.4.1 Incremental vs Full Rebuild Benchmark', () {
    List<StrokePoint> generateCenterline(int count) {
      final points = <StrokePoint>[];
      for (int i = 0; i < count; i++) {
        final t = i * 0.05;
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

    const testScales = [10, 100, 500, 1000, 2000, 5000, 10000];

    for (final count in testScales) {
      test(
          'Benchmark scale: $count centerline points (Full Rebuild vs Incremental Delta)',
          () {
        final points = generateCenterline(count);
        const builder = StrokeGeometryBuilder(
          widthProfile: DynamicWidthProfile(StrokeWidthConfig(
            baseWidth: 12.0,
            pressureEnabled: true,
            velocityEnabled: true,
          )),
          cap: StrokeCapType.round,
          join: StrokeJoinType.round,
        );

        // 1. FULL REBUILD MEASUREMENT at scale N
        // Measures rebuilding the entire stroke from index 0 to N
        builder.buildFromPoints(points); // Warmup
        final swFull = Stopwatch()..start();
        final iterations = count <= 1000 ? 20 : (count <= 5000 ? 5 : 2);
        StrokeOutline? fullOutline;
        for (int i = 0; i < iterations; i++) {
          fullOutline = builder.buildFromPoints(points);
        }
        swFull.stop();
        final fullRebuildMs =
            swFull.elapsedMicroseconds / (iterations * 1000.0);

        // 2. INCREMENTAL DELTA MEASUREMENT at step N
        // Measures calculating only the delta geometry for the latest arriving sample
        // (Join at point N-1, segment to N, and new end cap at N)
        final pPrev2 = points[math.max(0, count - 3)].position;
        final pPrev = points[math.max(0, count - 2)].position;
        final pCurr = points[count - 1].position;
        const rCurr = 6.0;

        final swInc = Stopwatch()..start();
        const incIterations = 1000;
        for (int i = 0; i < incIterations; i++) {
          final vIn = GeometryMath.normalize(pPrev - pPrev2);
          final vOut = GeometryMath.normalize(pCurr - pPrev);
          // Join computation at N-1
          StrokeJoinBuilder.buildJoin(
            center: pPrev,
            vIn: vIn,
            vOut: vOut,
            radius: rCurr,
            joinType: StrokeJoinType.round,
          );
          // End cap computation at N
          final nEnd = GeometryMath.leftNormal(vOut);
          StrokeCapBuilder.buildEndCap(
            center: pCurr,
            tangent: vOut,
            l: pCurr + nEnd * rCurr,
            r: pCurr - nEnd * rCurr,
            radius: rCurr,
            capType: StrokeCapType.round,
          );
        }
        swInc.stop();
        final incUpdateUs = swInc.elapsedMicroseconds / incIterations;
        final incUpdateMs = incUpdateUs / 1000.0;

        // Frame budget checks
        final exceeds120Hz = fullRebuildMs > 8.33;
        final exceeds60Hz = fullRebuildMs > 16.67;

        // ignore: avoid_print
        print('=== Scale: $count Centerline Points ===');
        // ignore: avoid_print
        print('  Contour Vertices:         ${fullOutline!.contour.length}');
        // ignore: avoid_print
        print(
            '  Full Rebuild Time:        ${fullRebuildMs.toStringAsFixed(3)} ms');
        // ignore: avoid_print
        print(
            '  Incremental Delta Time:   ${incUpdateMs.toStringAsFixed(4)} ms (${incUpdateUs.toStringAsFixed(1)} µs)');
        // ignore: avoid_print
        print(
            '  Speedup (Rebuild/Delta):  ${(fullRebuildMs / math.max(0.0001, incUpdateMs)).toStringAsFixed(1)}x');
        // ignore: avoid_print
        print('  Exceeds 120Hz (8.33ms):   $exceeds120Hz');
        // ignore: avoid_print
        print('  Exceeds 60Hz  (16.67ms):  $exceeds60Hz');

        expect(fullOutline.isNotEmpty, isTrue);
        expect(incUpdateMs,
            lessThan(0.5)); // Incremental step is always sub-millisecond O(1)
      });
    }
  });
}
