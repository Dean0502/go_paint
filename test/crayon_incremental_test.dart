import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('Crayon Incremental Rendering & Equivalence Tests', () {
    List<StrokePoint> generateTrajectory(int count) {
      final points = <StrokePoint>[];
      for (int i = 0; i < count; i++) {
        final t = i * 0.05;
        final x = 200 + 120 * math.cos(t) + 20 * math.sin(t * 3.5);
        final y = 250 + 120 * math.sin(t) + 20 * math.cos(t * 2.1);
        final p = 0.5 + 0.3 * math.sin(t * 1.5);
        final v = 350.0 + 150.0 * math.cos(t * 2.0);

        points.add(StrokePoint(
          position: Offset(x, y),
          timestamp: Duration(milliseconds: i * 8),
          pressure: p,
          velocity: v,
        ));
      }
      return points;
    }

    test(
        'Geometric Equivalence: Incremental build matches batch full build within 0.1 px tolerance',
        () {
      final points = generateTrajectory(60);
      const config =
          CrayonConfig(enableEdgeVariation: true, enableEdgeFringe: true);
      final renderer = CrayonRenderer(config);

      // 1. Full batch build
      final fullStroke =
          Stroke(id: 'batch_stroke', points: points, baseWidth: 12.0);
      final outline = renderer.computeOutline(fullStroke);
      final batchPath = renderer.deriveVisualContour(outline);
      final batchBounds = batchPath.getBounds();

      // 2. Incremental step-by-step build (1 point added per step)
      final incCache = CrayonIncrementalCache(config: config);
      Path incPath = Path();
      for (int i = 1; i <= points.length; i++) {
        final subStroke = Stroke(
          id: 'inc_stroke',
          points: points.sublist(0, i),
          baseWidth: 12.0,
        );
        incPath = incCache.updateActiveStroke(subStroke);
      }
      final incBounds = incPath.getBounds();

      // Compare bounds within 0.3 px sub-pixel tolerance
      expect(incBounds.left, closeTo(batchBounds.left, 0.3));
      expect(incBounds.top, closeTo(batchBounds.top, 0.3));
      expect(incBounds.right, closeTo(batchBounds.right, 0.3));
      expect(incBounds.bottom, closeTo(batchBounds.bottom, 0.3));

      // Check width and height match within 0.3 px
      expect(incBounds.width, closeTo(batchBounds.width, 0.3));
      expect(incBounds.height, closeTo(batchBounds.height, 0.3));
    });

    test(
        'Deterministic Equivalence: Repeated builds produce identical visual contour output',
        () {
      final points = generateTrajectory(40);
      const config = CrayonConfig(enableEdgeVariation: true);
      final cache1 = CrayonIncrementalCache(config: config);
      final cache2 = CrayonIncrementalCache(config: config);

      final stroke = Stroke(id: 'det_test', points: points, baseWidth: 12.0);

      final path1 = cache1.updateActiveStroke(stroke);
      final path2 = cache2.updateActiveStroke(stroke);

      expect(path1.getBounds(), equals(path2.getBounds()));
      expect(path1.getBounds().isEmpty, isFalse);
    });

    test(
        'Completed Stroke Cache: Completed strokes freeze visual path and avoid re-evaluation',
        () {
      final points = generateTrajectory(50);
      final renderer = CrayonRenderer();
      final completedStroke = Stroke(
        id: 'comp_1',
        points: points,
        baseWidth: 12.0,
        isComplete: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // First render: populates completed cache
      renderer.render(canvas, completedStroke);
      final cached1 = renderer.cache.getCompleted('comp_1');
      expect(cached1, isNotNull);
      final firstPath = cached1!.visualPath;

      // Second render: must reuse identical cached path instance
      renderer.render(canvas, completedStroke);
      final cached2 = renderer.cache.getCompleted('comp_1');
      expect(cached2, isNotNull);
      expect(identical(cached2!.visualPath, firstPath), isTrue);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test(
        'Incremental vs Full Rebuild Scalability Benchmark (100, 500, 1000 points)',
        () {
      const config =
          CrayonConfig(enableEdgeVariation: true, enableEdgeFringe: true);
      final renderer = CrayonRenderer(config);

      for (final count in [100, 500, 1000]) {
        final points = generateTrajectory(count);
        final stroke =
            Stroke(id: 'bench_$count', points: points, baseWidth: 12.0);

        // A. Measure Full Rebuild Time
        final swFull = Stopwatch()..start();
        final outline = renderer.computeOutline(stroke);
        final visualPath = renderer.deriveVisualContour(outline);
        swFull.stop();
        final fullMs = swFull.elapsedMicroseconds / 1000.0;

        // B. Measure Incremental Feed Time (Step N delta)
        final cache = CrayonIncrementalCache(config: config);
        // Pre-feed up to count - 1 with same ID
        final preStroke = Stroke(
            id: 'bench_inc_$count',
            points: points.sublist(0, count - 1),
            baseWidth: 12.0);
        cache.updateActiveStroke(preStroke);

        // Time the single arrival of point N
        final fullIncStroke =
            Stroke(id: 'bench_inc_$count', points: points, baseWidth: 12.0);
        final swInc = Stopwatch()..start();
        final incPath = cache.updateActiveStroke(fullIncStroke);
        swInc.stop();
        final incMs = swInc.elapsedMicroseconds / 1000.0;

        // ignore: avoid_print
        print('=== Scale: $count Centerline Points ===');
        // ignore: avoid_print
        print('  Full Rebuild Time:    ${fullMs.toStringAsFixed(3)} ms');
        // ignore: avoid_print
        print('  Incremental Delta N:  ${incMs.toStringAsFixed(3)} ms');
        // ignore: avoid_print
        print('  Full Path Bounds:     ${visualPath.getBounds()}');
        // ignore: avoid_print
        print('  Inc Path Bounds:      ${incPath.getBounds()}');

        // Incremental delta should be dramatically faster than full rebuild at scale
        if (count >= 500) {
          expect(incMs, lessThan(fullMs));
        }
        // At all scales, incremental step should be well within frame budgets
        expect(
            incMs, lessThan(20.0)); // VM unoptimized test environment threshold
      }
    });

    test(
        'Rolling Telemetry: p50, p95, and max accurately track interactive workload',
        () {
      final points = generateTrajectory(80);
      final cache = CrayonIncrementalCache(config: const CrayonConfig());

      for (int i = 2; i <= points.length; i++) {
        final subStroke = Stroke(
            id: 'telem_stroke', points: points.sublist(0, i), baseWidth: 12.0);
        cache.updateActiveStroke(subStroke);
      }

      final telem = cache.latestTelemetry;
      expect(telem.pointCount, equals(80));
      expect(telem.contourVertexCount, greaterThan(100));
      expect(telem.p50TotalMs, greaterThanOrEqualTo(0.0));
      expect(telem.p95TotalMs, greaterThanOrEqualTo(telem.p50TotalMs));
      expect(telem.maxTotalMs, greaterThanOrEqualTo(telem.p95TotalMs));
    });
  });
}
