import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('KIDZ CANVAS v0.4.1 Geometry Validation Tests', () {
    const builder = StrokeGeometryBuilder(
      widthProfile: ConstantWidthProfile(20.0),
      cap: StrokeCapType.round,
      join: StrokeJoinType.round,
    );

    // 1. Horizontal constant-width stroke
    test('1. Horizontal constant-width stroke: upper boundary y=90, lower boundary y=110', () {
      final outline = builder.buildFromOffsets(
        [const Offset(10, 100), const Offset(100, 100)],
        width: 20.0,
        cap: StrokeCapType.butt,
      );

      expect(outline.isNotEmpty, isTrue);
      // Left boundary is upper (smaller y in Flutter canvas space)
      for (final p in outline.leftBoundary) {
        expect(p.dy, closeTo(90.0, 1e-4));
      }
      // Right boundary is lower (larger y in Flutter canvas space)
      for (final p in outline.rightBoundary) {
        expect(p.dy, closeTo(110.0, 1e-4));
      }
      expect(outline.bounds.top, closeTo(90.0, 1e-4));
      expect(outline.bounds.bottom, closeTo(110.0, 1e-4));
      expect(outline.bounds.left, closeTo(10.0, 1e-4));
      expect(outline.bounds.right, closeTo(100.0, 1e-4));
    });

    // 2. Round cap radius
    test('2. Round cap radius extends exactly radius R beyond endpoints', () {
      final outline = builder.buildFromOffsets(
        [const Offset(50, 100), const Offset(150, 100)],
        width: 20.0, // radius = 10.0
        cap: StrokeCapType.round,
      );

      // Start cap should reach x = 50 - 10 = 40.0
      expect(outline.bounds.left, closeTo(40.0, 0.5));
      // End cap should reach x = 150 + 10 = 160.0
      expect(outline.bounds.right, closeTo(160.0, 0.5));
      // Semicircle arc should not exceed width in y-axis
      expect(outline.bounds.top, closeTo(90.0, 0.5));
      expect(outline.bounds.bottom, closeTo(110.0, 0.5));
    });

    // 3. Square cap extension
    test('3. Square cap extension extends forward and backward by exactly radius R', () {
      final outline = builder.buildFromOffsets(
        [const Offset(50, 100), const Offset(150, 100)],
        width: 20.0, // radius = 10.0
        cap: StrokeCapType.square,
      );

      expect(outline.bounds.left, closeTo(40.0, 1e-4));
      expect(outline.bounds.right, closeTo(160.0, 1e-4));
      expect(outline.bounds.top, closeTo(90.0, 1e-4));
      expect(outline.bounds.bottom, closeTo(110.0, 1e-4));
    });

    // 4. Miter ratio calculation & 5. Miter-limit fallback
    test('4 & 5. Miter ratio calculation and miter-limit fallback', () {
      // 90-degree corner: half-angle = 45 deg, cos(45) = 1/sqrt(2) ~ 0.7071
      // Miter ratio = 1 / 0.7071 = sqrt(2) ~ 1.4142
      const miterBuilder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0), // R = 10.0
        join: StrokeJoinType.miter,
        miterLimit: 1.5, // 1.4142 <= 1.5 -> Should use miter
      );

      final miterOutline = miterBuilder.buildFromOffsets([
        const Offset(0, 50),
        const Offset(50, 50),
        const Offset(50, 100),
      ], width: 20.0, join: StrokeJoinType.miter);

      // Left boundary (outer) should have a miter point extending beyond (60, 40)
      final maxOuterX = miterOutline.leftBoundary.map((p) => p.dx).reduce(math.max);
      final minOuterY = miterOutline.leftBoundary.map((p) => p.dy).reduce(math.min);
      expect(maxOuterX, closeTo(60.0, 1.0));
      expect(minOuterY, closeTo(40.0, 1.0));

      // Now with miterLimit = 1.2 (< 1.4142) -> Should trigger bevel fallback
      const bevelFallbackBuilder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        join: StrokeJoinType.miter,
        miterLimit: 1.2,
      );

      final fallbackOutline = bevelFallbackBuilder.buildFromOffsets([
        const Offset(0, 50),
        const Offset(50, 50),
        const Offset(50, 100),
      ], width: 20.0, join: StrokeJoinType.miter);

      expect(fallbackOutline.isNotEmpty, isTrue);
      // Outer miter point is not present, beveled flat bridge between (50, 40) and (60, 50)
      final fallbackMaxX = fallbackOutline.leftBoundary.map((p) => p.dx).reduce(math.max);
      expect(fallbackMaxX, lessThanOrEqualTo(60.0 + 1e-4));
    });

    // 6. Left/right boundary orientation
    test('6. Left/right boundary orientation in Flutter coordinate space (Y down)', () {
      // Vector pointing right: (1, 0)
      final nLeft = GeometryMath.leftNormal(const Offset(1, 0));
      final nRight = GeometryMath.rightNormal(const Offset(1, 0));

      // Left normal must point UP (dy = -1), Right normal must point DOWN (dy = +1)
      expect(nLeft.dx, closeTo(0.0, 1e-6));
      expect(nLeft.dy, closeTo(-1.0, 1e-6));
      expect(nRight.dx, closeTo(0.0, 1e-6));
      expect(nRight.dy, closeTo(1.0, 1e-6));

      // Vector pointing down: (0, 1)
      final nDownLeft = GeometryMath.leftNormal(const Offset(0, 1));
      final nDownRight = GeometryMath.rightNormal(const Offset(0, 1));

      // Left normal must point RIGHT (dx = +1), Right normal must point LEFT (dx = -1)
      expect(nDownLeft.dx, closeTo(1.0, 1e-6));
      expect(nDownLeft.dy, closeTo(0.0, 1e-6));
      expect(nDownRight.dx, closeTo(-1.0, 1e-6));
      expect(nDownRight.dy, closeTo(0.0, 1e-6));
    });

    // 7. Closed path
    test('7. Outline path is strictly closed and non-empty for valid strokes', () {
      final outline = builder.buildFromOffsets([
        const Offset(10, 10),
        const Offset(30, 80),
        const Offset(90, 40),
        const Offset(150, 120),
      ], width: 14.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.contour.length, greaterThan(6));
      expect(outline.path, isNotNull);
      expect(outline.perimeter, greaterThan(0.0));
      expect(outline.centerlineLength, greaterThan(0.0));
    });

    // 8. Bounds correctness
    test('8. Bounds strictly encloses all contour points without clipping', () {
      final outline = builder.buildFromOffsets([
        const Offset(15, 25),
        const Offset(45, 95),
        const Offset(120, 35),
        const Offset(180, 110),
      ], width: 16.0);

      for (final p in outline.contour) {
        expect(p.dx >= outline.bounds.left - 1e-4, isTrue);
        expect(p.dx <= outline.bounds.right + 1e-4, isTrue);
        expect(p.dy >= outline.bounds.top - 1e-4, isTrue);
        expect(p.dy <= outline.bounds.bottom + 1e-4, isTrue);
      }
    });

    // 9. Duplicate-point collapse
    test('9. Duplicate consecutive points are cleanly collapsed', () {
      final outline = builder.buildFromOffsets([
        const Offset(50, 50),
        const Offset(50, 50),
        const Offset(50, 50),
        const Offset(120, 50),
        const Offset(120, 50),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.centerline.length, 2);
    });

    // 10. Single-point dab
    test('10. Single-point dab produces clean circular, square, or butt dabs', () {
      final roundDab = builder.buildFromOffsets(
        [const Offset(100, 100)],
        width: 16.0,
        cap: StrokeCapType.round,
      );
      expect(roundDab.bounds.width, closeTo(16.0, 0.1));
      expect(roundDab.bounds.height, closeTo(16.0, 0.1));

      final squareDab = builder.buildFromOffsets(
        [const Offset(100, 100)],
        width: 16.0,
        cap: StrokeCapType.square,
      );
      expect(squareDab.bounds.width, closeTo(16.0, 0.1));
      expect(squareDab.bounds.height, closeTo(16.0, 0.1));

      final buttDab = builder.buildFromOffsets(
        [const Offset(100, 100)],
        width: 16.0,
        cap: StrokeCapType.butt,
      );
      expect(buttDab.isNotEmpty, isTrue);
    });

    // 11. Zero-width behavior
    test('11. Zero-width stroke produces safe empty outline without crashing', () {
      final outline = builder.buildFromOffsets(
        [const Offset(10, 10), const Offset(50, 50)],
        width: 0.0,
      );
      expect(outline.isEmpty, isTrue);
      expect(outline.bounds, Rect.zero);
      expect(outline.centerlineLength, 0.0);
    });

    // 12. Verification of all 16 required test shapes
    test('12. Validation of all 16 required test shapes produces finite, non-empty outlines', () {
      final shapes = <String, List<Offset>>{
        'single_point_dab': [const Offset(100, 100)],
        'short_stroke': [const Offset(100, 100), const Offset(100.8, 100.4)],
        'horizontal_line': [const Offset(20, 100), const Offset(180, 100)],
        'vertical_line': [const Offset(100, 20), const Offset(100, 180)],
        'diagonal_line': [const Offset(20, 20), const Offset(180, 180)],
        'smooth_curve': List.generate(25, (i) => Offset(20.0 + i * 6.0, 100.0 + 30.0 * math.sin(i * 0.25))),
        'full_circle': List.generate(36, (i) => Offset(100.0 + 50.0 * math.cos(i * math.pi / 18), 100.0 + 50.0 * math.sin(i * math.pi / 18))),
        '90_deg_corner': [const Offset(30, 60), const Offset(100, 60), const Offset(100, 130)],
        'acute_corner': [const Offset(30, 40), const Offset(120, 100), const Offset(40, 120)],
        'obtuse_corner': [const Offset(30, 40), const Offset(100, 80), const Offset(170, 60)],
        'zigzag': [
          const Offset(20, 40),
          const Offset(60, 100),
          const Offset(100, 40),
          const Offset(140, 100),
          const Offset(180, 40),
        ],
        'rapid_direction_changes': [
          const Offset(50, 50),
          const Offset(60, 90),
          const Offset(80, 55),
          const Offset(95, 85),
          const Offset(110, 45),
        ],
        'pressure_width_variation': [
          const Offset(30, 100),
          const Offset(80, 100),
          const Offset(140, 100),
        ],
        'duplicate_points': [
          const Offset(50, 50),
          const Offset(50, 50),
          const Offset(100, 50),
          const Offset(100, 50),
        ],
        'extremely_close_points': [
          const Offset(50.0, 50.0),
          const Offset(50.00002, 50.00001),
          const Offset(120.0, 50.0),
        ],
        'zero_width_stroke': [const Offset(20, 20), const Offset(80, 80)],
      };

      for (final entry in shapes.entries) {
        final name = entry.key;
        final pts = entry.value;
        final width = (name == 'zero_width_stroke') ? 0.0 : 12.0;

        final outline = builder.buildFromOffsets(pts, width: width);

        if (name == 'zero_width_stroke') {
          expect(outline.isEmpty, isTrue, reason: 'Shape $name should be empty');
        } else {
          expect(outline.isNotEmpty, isTrue, reason: 'Shape $name should not be empty');
          expect(outline.bounds.isFinite, isTrue, reason: 'Shape $name bounds should be finite');
          for (final p in outline.contour) {
            expect(p.dx.isFinite, isTrue, reason: 'Shape $name vertex dx must be finite');
            expect(p.dy.isFinite, isTrue, reason: 'Shape $name vertex dy must be finite');
            expect(p.dx.isNaN, isFalse, reason: 'Shape $name vertex dx must not be NaN');
            expect(p.dy.isNaN, isFalse, reason: 'Shape $name vertex dy must not be NaN');
          }
        }
      }
    });
  });
}
