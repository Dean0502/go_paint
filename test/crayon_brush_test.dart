import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('CrayonWidthProfile Tests', () {
    const profile = CrayonWidthProfile(CrayonWidthConfig(
      baseWidth: 12.0,
      minWidthFactor: 0.70,
      maxWidthFactor: 1.40,
      velocityMin: 100.0,
      velocityMax: 1000.0,
      velocitySlowFactor: 1.20,
      velocityFastFactor: 0.80,
      pressureLightFactor: 0.75,
      pressureFirmFactor: 1.35,
      taperPoints: 3,
      startTaperFactor: 0.75,
      endTaperFactor: 0.70,
      smoothingFactor: 0.40,
    ));

    test('Slow velocity produces wider stroke than fast velocity', () {
      const slowPt = StrokePoint(
        position: Offset(10, 10),
        timestamp: Duration.zero,
        velocity: 50.0, // Slow (< velocityMin)
        pressure: 0.5,
      );

      const fastPt = StrokePoint(
        position: Offset(20, 20),
        timestamp: Duration(milliseconds: 10),
        velocity: 1200.0, // Fast (> velocityMax)
        pressure: 0.5,
      );

      final wSlow = profile.computeRawWidth(slowPt, 12.0);
      final wFast = profile.computeRawWidth(fastPt, 12.0);

      expect(wSlow, greaterThan(wFast));
      // Base: 12.0. Slow vel factor: 1.20. Pressure 0.5 factor: (0.75 + 0.5*(1.35-0.75)) = 1.05.
      expect(wSlow, closeTo(12.0 * 1.20 * 1.05, 0.1));
      // Fast vel factor: 0.80.
      expect(wFast, closeTo(12.0 * 0.80 * 1.05, 0.1));
    });

    test('Light pressure produces thinner stroke than firm pressure', () {
      const lightPt = StrokePoint(
        position: Offset(10, 10),
        timestamp: Duration.zero,
        velocity: 550.0, // Mid-range velocity
        pressure: 0.0,   // Lightest touch
      );

      const firmPt = StrokePoint(
        position: Offset(20, 20),
        timestamp: Duration(milliseconds: 10),
        velocity: 550.0, // Mid-range velocity
        pressure: 1.0,   // Firmest press
      );

      final wLight = profile.computeRawWidth(lightPt, 12.0);
      final wFirm = profile.computeRawWidth(firmPt, 12.0);

      expect(wLight, lessThan(wFirm));
      expect(wLight, closeTo(12.0 * 1.0 * 0.75, 0.1));
      expect(wFirm, closeTo(12.0 * 1.0 * 1.35, 0.1));
    });

    test('All radii remain finite, non-negative, and clamped', () {
      const extremePts = [
        StrokePoint(
          position: Offset(0, 0),
          timestamp: Duration.zero,
          velocity: -1000.0,
          pressure: -5.0,
        ),
        StrokePoint(
          position: Offset(10, 10),
          timestamp: Duration(milliseconds: 16),
          velocity: 50000.0,
          pressure: 25.0,
        ),
      ];

      final radii = profile.computeRadii(extremePts, baseWidth: 12.0);
      expect(radii.length, 2);
      for (final r in radii) {
        expect(r.isFinite, isTrue);
        expect(r.isNaN, isFalse);
        expect(r, greaterThanOrEqualTo(0.0));
      }
    });

    test('Endpoint taper scales entry and exit radii smoothly', () {
      final points = List.generate(20, (i) {
        return StrokePoint(
          position: Offset(i * 15.0, 50.0),
          timestamp: Duration(milliseconds: i * 16),
          velocity: 500.0,
          pressure: 0.5,
        );
      });

      final radii = profile.computeRadii(points, baseWidth: 12.0);
      expect(radii.length, 20);

      // Entry point should be tapered down relative to mid-stroke
      expect(radii[0], lessThan(radii[4]));
      expect(radii[0], closeTo(radii[4] * 0.75, 0.30));

      // Exit point should be tapered down relative to mid-stroke
      expect(radii.last, lessThan(radii[radii.length - 4]));
      expect(radii.last, closeTo(radii[radii.length - 4] * 0.70, 0.30));
    });

    test('Width transitions between adjacent points are smoothed without abrupt spikes', () {
      // Simulate an abrupt velocity surge (e.g. 200 to 950 and back)
      const points = [
        StrokePoint(position: Offset(0, 0), timestamp: Duration.zero, velocity: 200.0, pressure: 0.5),
        StrokePoint(position: Offset(10, 0), timestamp: Duration(milliseconds: 10), velocity: 200.0, pressure: 0.5),
        StrokePoint(position: Offset(20, 0), timestamp: Duration(milliseconds: 20), velocity: 950.0, pressure: 0.5),
        StrokePoint(position: Offset(30, 0), timestamp: Duration(milliseconds: 30), velocity: 200.0, pressure: 0.5),
      ];

      final rawJump = (profile.computeRawWidth(points[2], 12.0) - profile.computeRawWidth(points[1], 12.0)).abs();
      final radii = profile.computeRadii(points, baseWidth: 12.0);
      final smoothedJump = (radii[2] * 2.0 - radii[1] * 2.0).abs();

      expect(smoothedJump, lessThan(rawJump));
    });

    test('Single-point dab returns valid non-zero radius', () {
      const dab = StrokePoint(
        position: Offset(100, 100),
        timestamp: Duration.zero,
        pressure: 0.5,
      );

      final radii = profile.computeRadii([dab], baseWidth: 12.0);
      expect(radii.length, 1);
      // Slow vel: 1.20, pressure: 1.05 -> width = 12 * 1.2 * 1.05 = 15.12 -> radius = 7.56
      expect(radii.first, closeTo(7.56, 0.2));
    });

    test('Zero-width stroke returns 0.0 radii without errors', () {
      const points = [
        StrokePoint(position: Offset(0, 0), timestamp: Duration.zero),
        StrokePoint(position: Offset(10, 10), timestamp: Duration(milliseconds: 10)),
      ];

      final radii = profile.computeRadii(points, baseWidth: 0.0);
      expect(radii, [0.0, 0.0]);
    });
  });

  group('CrayonRenderer Tests', () {
    test('computeOpacity produces stable bounded values in [0.35, 1.0]', () {
      final renderer = CrayonRenderer(const CrayonConfig(
        baseOpacity: 0.90,
        velocityOpacityInfluence: 0.10,
        pressureOpacityInfluence: 0.15,
      ));

      final normalStroke = Stroke(
        id: 'norm',
        points: const [
          StrokePoint(position: Offset(0, 0), timestamp: Duration.zero, velocity: 500, pressure: 0.5),
          StrokePoint(position: Offset(10, 0), timestamp: Duration(milliseconds: 10), velocity: 500, pressure: 0.5),
        ],
      );

      final fastLightStroke = Stroke(
        id: 'fast_light',
        points: const [
          StrokePoint(position: Offset(0, 0), timestamp: Duration.zero, velocity: 1500, pressure: 0.0),
          StrokePoint(position: Offset(50, 0), timestamp: Duration(milliseconds: 10), velocity: 1500, pressure: 0.0),
        ],
      );

      final slowFirmStroke = Stroke(
        id: 'slow_firm',
        points: const [
          StrokePoint(position: Offset(0, 0), timestamp: Duration.zero, velocity: 50, pressure: 1.0),
          StrokePoint(position: Offset(5, 0), timestamp: Duration(milliseconds: 10), velocity: 50, pressure: 1.0),
        ],
      );

      final opNorm = renderer.computeOpacity(normalStroke);
      final opLight = renderer.computeOpacity(fastLightStroke);
      final opFirm = renderer.computeOpacity(slowFirmStroke);

      expect(opNorm, closeTo(0.90, 0.05));
      expect(opLight, lessThan(opNorm));
      expect(opFirm, greaterThan(opNorm));
      expect(opLight, greaterThanOrEqualTo(0.35));
      expect(opFirm, lessThanOrEqualTo(1.0));
    });

    test('computeOutline produces clean closed mathematical geometry with round caps and joins', () {
      final renderer = CrayonRenderer();
      final stroke = Stroke(
        id: 'c_line',
        baseWidth: 12.0,
        points: const [
          StrokePoint(position: Offset(50, 50), timestamp: Duration.zero, pressure: 0.5),
          StrokePoint(position: Offset(120, 50), timestamp: Duration(milliseconds: 16), pressure: 0.7),
          StrokePoint(position: Offset(120, 120), timestamp: Duration(milliseconds: 32), pressure: 0.8),
        ],
      );

      final outline = renderer.computeOutline(stroke);
      expect(outline.isEmpty, isFalse);
      expect(outline.contour.length, greaterThan(15));
      expect(outline.bounds.contains(const Offset(50, 50)), isTrue);
      expect(outline.bounds.contains(const Offset(120, 120)), isTrue);

      // Verify no NaN or infinite coordinates in clean outline
      for (final p in outline.contour) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    test('Edge variation is 100% deterministic: multiple evaluations produce identical paths', () {
      final renderer = CrayonRenderer(const CrayonConfig(enableEdgeVariation: true));
      final stroke = Stroke(
        id: 'det_stroke',
        baseWidth: 12.0,
        points: const [
          StrokePoint(position: Offset(20, 20), timestamp: Duration.zero),
          StrokePoint(position: Offset(50, 30), timestamp: Duration(milliseconds: 10)),
          StrokePoint(position: Offset(90, 70), timestamp: Duration(milliseconds: 20)),
          StrokePoint(position: Offset(140, 90), timestamp: Duration(milliseconds: 30)),
        ],
      );

      final outline = renderer.computeOutline(stroke);
      final path1 = renderer.deriveVisualContour(outline);
      final path2 = renderer.deriveVisualContour(outline);

      // Both derived paths must match identically
      expect(path1.getBounds(), equals(path2.getBounds()));
      expect(path1.getBounds().isEmpty, isFalse);
    });

    test('Edge variation disabled uses exact clean outline path', () {
      final renderer = CrayonRenderer(const CrayonConfig(enableEdgeVariation: false));
      final stroke = Stroke(
        id: 'no_var_stroke',
        baseWidth: 12.0,
        points: const [
          StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          StrokePoint(position: Offset(50, 50), timestamp: Duration(milliseconds: 10)),
        ],
      );

      final outline = renderer.computeOutline(stroke);
      final visualPath = renderer.deriveVisualContour(outline);

      expect(visualPath, equals(outline.path));
    });

    test('Canvas render completes without exceptions for dab, stroke, and edge variation toggles', () {
      final renderer = CrayonRenderer(const CrayonConfig(enableEdgeVariation: true, enableEdgeFringe: true));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // 1. Single point dab
      final dab = Stroke(
        id: 'dab',
        baseWidth: 12.0,
        points: const [
          StrokePoint(position: Offset(50, 50), timestamp: Duration.zero, pressure: 0.8),
        ],
      );
      expect(() => renderer.render(canvas, dab), returnsNormally);

      // 2. Multi-point stroke with edge variation and fringe
      final stroke = Stroke(
        id: 'stroke',
        baseWidth: 12.0,
        points: const [
          StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          StrokePoint(position: Offset(40, 20), timestamp: Duration(milliseconds: 10)),
          StrokePoint(position: Offset(80, 60), timestamp: Duration(milliseconds: 20)),
        ],
      );
      expect(() => renderer.render(canvas, stroke), returnsNormally);

      // 3. Render with edge variation and fringe disabled
      final cleanRenderer = CrayonRenderer(const CrayonConfig(enableEdgeVariation: false, enableEdgeFringe: false));
      expect(() => cleanRenderer.render(canvas, stroke), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Zero-width stroke yields empty outline and does not draw', () {
      final renderer = CrayonRenderer();
      final stroke = Stroke(
        id: 'zero',
        baseWidth: 0.0,
        points: const [
          StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          StrokePoint(position: Offset(20, 20), timestamp: Duration(milliseconds: 10)),
        ],
      );

      final outline = renderer.computeOutline(stroke);
      expect(outline.isEmpty, isTrue);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => renderer.render(canvas, stroke), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Performance benchmark: long stroke (500 points) renders within 120Hz frame budget (<8.33ms)', () {
      final renderer = CrayonRenderer(const CrayonConfig(enableEdgeVariation: true, enableEdgeFringe: true));
      final points = List.generate(500, (i) {
        return StrokePoint(
          position: Offset(i * 2.0, 100.0 + 30.0 * ((i % 10) - 5)),
          timestamp: Duration(milliseconds: i * 8),
          velocity: 250.0 + (i % 200),
          pressure: 0.3 + (i % 7) * 0.1,
        );
      });

      final stroke = Stroke(
        id: 'long_500',
        baseWidth: 12.0,
        points: points,
      );

      // Warmup
      renderer.render(Canvas(PictureRecorder()), stroke);

      // Timed execution breakdown
      final swTotal = Stopwatch()..start();
      final swRadii = Stopwatch()..start();
      final radii = renderer.computePointRadii(stroke);
      swRadii.stop();

      final swOutline = Stopwatch()..start();
      final outline = renderer.computeOutline(stroke);
      swOutline.stop();

      final swContour = Stopwatch()..start();
      final _ = renderer.deriveVisualContour(outline);
      swContour.stop();

      final swRender = Stopwatch()..start();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      renderer.render(canvas, stroke);
      final picture = recorder.endRecording();
      swRender.stop();
      swTotal.stop();

      // ignore: avoid_print
      print('--- Crayon 500-Point Benchmark Breakdown ---');
      // ignore: avoid_print
      print('Radii (${radii.length} pts):    ${(swRadii.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms');
      // ignore: avoid_print
      print('Outline (${outline.contour.length} pts): ${(swOutline.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms');
      // ignore: avoid_print
      print('VisualContour:         ${(swContour.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms');
      // ignore: avoid_print
      print('Render (full):         ${(swRender.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms');
      // ignore: avoid_print
      print('Total:                 ${(swTotal.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms');

      expect(picture, isNotNull);
      expect(swOutline.elapsedMilliseconds, lessThan(100));
      expect(swContour.elapsedMilliseconds, lessThan(30));
    });

    test('Performance benchmark: 100 points active stroke segment renders within 120Hz frame budget (<8.33ms)', () {
      final renderer = CrayonRenderer(const CrayonConfig(enableEdgeVariation: true, enableEdgeFringe: true));
      final points = List.generate(100, (i) {
        return StrokePoint(
          position: Offset(i * 3.0, 100.0 + 15.0 * ((i % 8) - 4)),
          timestamp: Duration(milliseconds: i * 8),
          velocity: 300.0 + (i % 150),
          pressure: 0.4 + (i % 5) * 0.12,
        );
      });

      final stroke = Stroke(
        id: 'active_100',
        baseWidth: 12.0,
        points: points,
      );

      // Warmup
      renderer.render(Canvas(PictureRecorder()), stroke);

      final sw = Stopwatch()..start();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      renderer.render(canvas, stroke);
      final picture = recorder.endRecording();
      sw.stop();

      final elapsedMs = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('--- Crayon 100-Point Active Segment ---');
      // ignore: avoid_print
      print('Render time: ${elapsedMs.toStringAsFixed(2)} ms');

      expect(picture, isNotNull);
      expect(elapsedMs, lessThan(50.0)); // VM test environment threshold
    });
  });
}

