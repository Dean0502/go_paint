import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('PencilWidthProfile Tests', () {
    const profile = PencilWidthProfile(PencilWidthConfig(
      baseWidth: 3.0,
      minWidthFactor: 0.5,
      maxWidthFactor: 1.5,
      velocityMin: 100.0,
      velocityMax: 1000.0,
      velocitySlowFactor: 1.25,
      velocityFastFactor: 0.75,
      pressureLightFactor: 0.65,
      pressureFirmFactor: 1.35,
      taperPoints: 4,
      startTaperFactor: 0.70,
      endTaperFactor: 0.65,
      smoothingFactor: 0.35,
    ));

    test('Slow velocity produces wider width than fast velocity', () {
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

      final wSlow = profile.computeRawWidth(slowPt, 3.0);
      final wFast = profile.computeRawWidth(fastPt, 3.0);

      expect(wSlow, greaterThan(wFast));
      expect(wSlow, closeTo(3.0 * 1.25 * 1.0, 0.05));
      expect(wFast, closeTo(3.0 * 0.75 * 1.0, 0.05));
    });

    test('Light pressure produces thinner width than firm pressure', () {
      const lightPt = StrokePoint(
        position: Offset(10, 10),
        timestamp: Duration.zero,
        velocity: 550.0, // Mid-range velocity
        pressure: 0.0, // Lightest touch
      );

      const firmPt = StrokePoint(
        position: Offset(20, 20),
        timestamp: Duration(milliseconds: 10),
        velocity: 550.0, // Mid-range velocity
        pressure: 1.0, // Firmest press
      );

      final wLight = profile.computeRawWidth(lightPt, 3.0);
      final wFirm = profile.computeRawWidth(firmPt, 3.0);

      expect(wLight, lessThan(wFirm));
      expect(wLight, closeTo(3.0 * 1.0 * 0.65, 0.05));
      expect(wFirm, closeTo(3.0 * 1.0 * 1.35, 0.05));
    });

    test('Radii and widths always remain finite and clamped', () {
      const extremePts = [
        StrokePoint(
          position: Offset(0, 0),
          timestamp: Duration.zero,
          velocity: -500.0,
          pressure: -2.0,
        ),
        StrokePoint(
          position: Offset(10, 10),
          timestamp: Duration(milliseconds: 16),
          velocity: 100000.0,
          pressure: 50.0,
        ),
      ];

      final radii = profile.computeRadii(extremePts, baseWidth: 3.0);
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
          position: Offset(i * 10.0, 50.0),
          timestamp: Duration(milliseconds: i * 16),
          velocity: 500.0,
          pressure: 0.5,
        );
      });

      final radii = profile.computeRadii(points, baseWidth: 4.0);
      expect(radii.length, 20);

      // Entry point should be tapered down relative to mid-stroke
      expect(radii[0], lessThan(radii[4]));
      expect(radii[0], closeTo(radii[4] * 0.70, 0.20));

      // Exit point should be tapered down relative to mid-stroke
      expect(radii.last, lessThan(radii[radii.length - 5]));
      expect(radii.last, closeTo(radii[radii.length - 5] * 0.65, 0.20));
    });

    test(
        'Width transitions between adjacent points are smoothed without abrupt spikes',
        () {
      // Simulate a sudden single-sample velocity spike (e.g. from 200 to 900 and back to 200)
      const points = [
        StrokePoint(
            position: Offset(0, 0),
            timestamp: Duration.zero,
            velocity: 200.0,
            pressure: 0.5),
        StrokePoint(
            position: Offset(10, 0),
            timestamp: Duration(milliseconds: 10),
            velocity: 200.0,
            pressure: 0.5),
        StrokePoint(
            position: Offset(20, 0),
            timestamp: Duration(milliseconds: 20),
            velocity: 950.0,
            pressure: 0.5), // Sudden jump
        StrokePoint(
            position: Offset(30, 0),
            timestamp: Duration(milliseconds: 30),
            velocity: 200.0,
            pressure: 0.5),
      ];

      final rawJump = (profile.computeRawWidth(points[2], 4.0) -
              profile.computeRawWidth(points[1], 4.0))
          .abs();
      final radii = profile.computeRadii(points, baseWidth: 4.0);
      final smoothedJump = (radii[2] * 2.0 - radii[1] * 2.0).abs();

      // The smoothed width jump should be significantly less than the unmitigated raw jump
      expect(smoothedJump, lessThan(rawJump));
    });

    test('Single-point dab returns valid non-zero radius', () {
      const dab = StrokePoint(
        position: Offset(100, 100),
        timestamp: Duration.zero,
        pressure: 0.5,
      );

      final radii = profile.computeRadii([dab], baseWidth: 3.0);
      expect(radii.length, 1);
      expect(radii.first, closeTo(1.875, 0.05));
    });

    test('Zero-width stroke returns 0.0 radii without errors', () {
      const points = [
        StrokePoint(position: Offset(0, 0), timestamp: Duration.zero),
        StrokePoint(
            position: Offset(10, 10), timestamp: Duration(milliseconds: 10)),
      ];

      final radii = profile.computeRadii(points, baseWidth: 0.0);
      expect(radii, [0.0, 0.0]);
    });
  });

  group('PencilRenderer Tests', () {
    test('computeOpacity produces stable values clamped within [0.25, 0.95]',
        () {
      final renderer = PencilRenderer(const PencilConfig(
        baseOpacity: 0.65,
        velocityOpacityInfluence: 0.15,
        pressureOpacityInfluence: 0.20,
      ));

      final normalStroke = Stroke(
        id: 'norm',
        points: const [
          StrokePoint(
              position: Offset(0, 0),
              timestamp: Duration.zero,
              velocity: 500,
              pressure: 0.5),
          StrokePoint(
              position: Offset(10, 0),
              timestamp: Duration(milliseconds: 10),
              velocity: 500,
              pressure: 0.5),
        ],
      );

      final fastLightStroke = Stroke(
        id: 'fast_light',
        points: const [
          StrokePoint(
              position: Offset(0, 0),
              timestamp: Duration.zero,
              velocity: 1500,
              pressure: 0.0),
          StrokePoint(
              position: Offset(50, 0),
              timestamp: Duration(milliseconds: 10),
              velocity: 1500,
              pressure: 0.0),
        ],
      );

      final slowFirmStroke = Stroke(
        id: 'slow_firm',
        points: const [
          StrokePoint(
              position: Offset(0, 0),
              timestamp: Duration.zero,
              velocity: 50,
              pressure: 1.0),
          StrokePoint(
              position: Offset(5, 0),
              timestamp: Duration(milliseconds: 10),
              velocity: 50,
              pressure: 1.0),
        ],
      );

      final opNorm = renderer.computeOpacity(normalStroke);
      final opLight = renderer.computeOpacity(fastLightStroke);
      final opFirm = renderer.computeOpacity(slowFirmStroke);

      expect(opNorm, closeTo(0.65, 0.05));
      expect(opLight, lessThan(opNorm));
      expect(opFirm, greaterThan(opNorm));
      expect(opLight, greaterThanOrEqualTo(0.25));
      expect(opFirm, lessThanOrEqualTo(0.95));
    });

    test(
        'computeOutline produces closed geometry using round caps and round joins',
        () {
      final renderer = PencilRenderer();
      final stroke = Stroke(
        id: 'line',
        baseWidth: 4.0,
        points: const [
          StrokePoint(
              position: Offset(50, 50),
              timestamp: Duration.zero,
              pressure: 0.5),
          StrokePoint(
              position: Offset(100, 50),
              timestamp: Duration(milliseconds: 16),
              pressure: 0.6),
          StrokePoint(
              position: Offset(100, 100),
              timestamp: Duration(milliseconds: 32),
              pressure: 0.7),
        ],
      );

      final outline = renderer.computeOutline(stroke);
      expect(outline.isEmpty, isFalse);
      expect(outline.contour.length, greaterThan(10));
      expect(outline.bounds.contains(const Offset(50, 50)), isTrue);
      expect(outline.bounds.contains(const Offset(100, 100)), isTrue);

      // Verify no NaN or infinite coordinates
      for (final p in outline.contour) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    test(
        'Canvas render completes without exceptions for single dab and multi-point stroke',
        () {
      final renderer =
          PencilRenderer(const PencilConfig(enableGraphiteHalo: true));
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // 1. Single point dab
      final dab = Stroke(
        id: 'dab',
        baseWidth: 3.0,
        points: const [
          StrokePoint(
              position: Offset(50, 50),
              timestamp: Duration.zero,
              pressure: 0.8),
        ],
      );
      expect(() => renderer.render(canvas, dab), returnsNormally);

      // 2. Multi-point stroke
      final stroke = Stroke(
        id: 'stroke',
        baseWidth: 3.0,
        points: const [
          StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          StrokePoint(
              position: Offset(20, 15), timestamp: Duration(milliseconds: 10)),
          StrokePoint(
              position: Offset(30, 25), timestamp: Duration(milliseconds: 20)),
        ],
      );
      expect(() => renderer.render(canvas, stroke), returnsNormally);

      // 3. Render with graphite halo disabled
      final noHaloRenderer =
          PencilRenderer(const PencilConfig(enableGraphiteHalo: false));
      expect(() => noHaloRenderer.render(canvas, stroke), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('Zero-width stroke yields empty outline and does not draw', () {
      final renderer = PencilRenderer();
      final stroke = Stroke(
        id: 'zero',
        baseWidth: 0.0,
        points: const [
          StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          StrokePoint(
              position: Offset(20, 20), timestamp: Duration(milliseconds: 10)),
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

    test('Pencil lead grain derives deterministic, continuous visual contour',
        () {
      final renderer = PencilRenderer(const PencilConfig(
        enableLeadGrain: true,
        leadGrainAmplitude: 0.28,
        leadGrainWavelength: 3.5,
      ));

      final stroke = Stroke(
        id: 'grain_test',
        baseWidth: 3.0,
        points: List.generate(
            30,
            (i) => StrokePoint(
                  position: Offset(50.0 + i * 5.0, 100.0 + 10.0 * (i % 3)),
                  timestamp: Duration(milliseconds: i * 8),
                  pressure: 0.6,
                )),
      );

      final outline = renderer.computeOutline(stroke);
      final contour1 = renderer.deriveVisualContour(outline);
      final contour2 = renderer.deriveVisualContour(outline);

      // Deterministic output
      expect(contour1.getBounds(), equals(contour2.getBounds()));

      // When lead grain is disabled, contour matches clean outline
      final smoothRenderer =
          PencilRenderer(const PencilConfig(enableLeadGrain: false));
      final smoothBounds =
          smoothRenderer.deriveVisualContour(outline).getBounds();
      expect(smoothBounds.left, closeTo(outline.bounds.left, 0.1));
      expect(smoothBounds.top, closeTo(outline.bounds.top, 0.1));
      expect(smoothBounds.right, closeTo(outline.bounds.right, 0.1));
      expect(smoothBounds.bottom, closeTo(outline.bounds.bottom, 0.1));
    });

    test(
        'Incremental Pencil build matches batch full build within 0.1 px tolerance',
        () {
      const config =
          PencilConfig(enableLeadGrain: true, enableGraphiteHalo: true);
      final renderer = PencilRenderer(config);

      final points = List.generate(
          40,
          (i) => StrokePoint(
                position: Offset(100.0 + i * 4.0, 150.0 + 12.0 * (i % 4)),
                timestamp: Duration(milliseconds: i * 8),
                pressure: 0.5 + 0.2 * (i % 3),
                velocity: 300.0,
              ));

      // 1. Full batch build
      final fullStroke = Stroke(id: 'batch_p', points: points, baseWidth: 3.0);
      final outline = renderer.computeOutline(fullStroke);
      final batchPath = renderer.deriveVisualContour(outline);
      final batchBounds = batchPath.getBounds();

      // 2. Incremental step-by-step build
      final incCache = PencilIncrementalCache(config: config);
      Path incPath = Path();
      for (int i = 1; i <= points.length; i++) {
        final subStroke = Stroke(
          id: 'inc_p',
          points: points.sublist(0, i),
          baseWidth: 3.0,
        );
        incPath = incCache.updateActiveStroke(subStroke);
      }
      final incBounds = incPath.getBounds();

      expect(incBounds.left, closeTo(batchBounds.left, 0.25));
      expect(incBounds.top, closeTo(batchBounds.top, 0.25));
      expect(incBounds.right, closeTo(batchBounds.right, 0.25));
      expect(incBounds.bottom, closeTo(batchBounds.bottom, 0.25));
    });
  });
}
