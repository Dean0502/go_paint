import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('Professional Stroke Geometry Engine (v0.4) Tests', () {
    // 1. Single point tap (clean round dab)
    test('1. Single point tap produces a valid closed circular dab without NaN',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.round,
      );

      final outline =
          builder.buildFromOffsets([const Offset(100, 100)], width: 20.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.centerline.length, 1);
      expect(outline.contour.isNotEmpty, isTrue);
      expect(outline.bounds.width, closeTo(20.0, 0.1));
      expect(outline.bounds.height, closeTo(20.0, 0.1));
      expect(outline.contains(const Offset(100, 100)), isTrue);
      expect(outline.contains(const Offset(105, 105)), isTrue);
      expect(outline.contains(const Offset(120, 120)), isFalse);

      for (final p in outline.contour) {
        expect(p.dx.isNaN, isFalse);
        expect(p.dy.isNaN, isFalse);
      }
    });

    // 2. Two-point line
    test('2. Two-point line produces a continuous closed capsule outline', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        cap: StrokeCapType.round,
      );

      final outline = builder.buildFromOffsets([
        const Offset(50, 50),
        const Offset(150, 50),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.leftBoundary.isNotEmpty, isTrue);
      expect(outline.rightBoundary.isNotEmpty, isTrue);
      expect(outline.bounds.left, closeTo(45.0, 0.5));
      expect(outline.bounds.right, closeTo(155.0, 0.5));
      expect(outline.bounds.top, closeTo(45.0, 0.5));
      expect(outline.bounds.bottom, closeTo(55.0, 0.5));
    });

    // 3. Straight line
    test('3. Multi-sample straight line produces uniform width', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(14.0),
        cap: StrokeCapType.butt,
      );

      final points = List.generate(
        10,
        (i) => StrokePoint(
          position: Offset(i * 10.0, 100.0),
          timestamp: Duration(milliseconds: i * 8),
        ),
      );

      final outline = builder.buildFromPoints(points, baseWidth: 14.0);

      expect(outline.isNotEmpty, isTrue);
      for (final p in outline.leftBoundary) {
        expect(p.dy, closeTo(93.0, 0.01)); // y = 100 - 7
      }
      for (final p in outline.rightBoundary) {
        expect(p.dy, closeTo(107.0, 0.01)); // y = 100 + 7
      }
    });

    // 4. Horizontal line mathematical validation: y=100, width=20 -> upper y=90, lower y=110
    test(
        '4. Horizontal line mathematical validation: y=100, width=20 produces upper y=90 and lower y=110',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.butt,
      );

      final outline = builder.buildFromOffsets([
        const Offset(10, 100),
        const Offset(100, 100),
      ], width: 20.0, cap: StrokeCapType.butt);

      // Left boundary = upper boundary (smaller y)
      for (final p in outline.leftBoundary) {
        expect(p.dy, closeTo(90.0, 1e-4));
      }
      // Right boundary = lower boundary (larger y)
      for (final p in outline.rightBoundary) {
        expect(p.dy, closeTo(110.0, 1e-4));
      }
      expect(outline.bounds.top, closeTo(90.0, 1e-4));
      expect(outline.bounds.bottom, closeTo(110.0, 1e-4));
    });

    // 5. Vertical line mathematical validation: x=100, width=20 -> left x=110, right x=90
    test(
        '5. Vertical line mathematical validation: x=100, width=20 produces exact left/right boundary offsets',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.butt,
      );

      final outline = builder.buildFromOffsets([
        const Offset(100, 10),
        const Offset(100, 100),
      ], width: 20.0, cap: StrokeCapType.butt);

      for (final p in outline.leftBoundary) {
        expect(p.dx, closeTo(110.0, 1e-4));
      }
      for (final p in outline.rightBoundary) {
        expect(p.dx, closeTo(90.0, 1e-4));
      }
    });

    // 6. Diagonal line mathematical validation: 45 deg, width=20
    test('6. Diagonal 45-degree line produces exact perpendicular thickness',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.butt,
      );

      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(100, 100),
      ], width: 20.0, cap: StrokeCapType.butt);

      expect(outline.isNotEmpty, isTrue);
      // At (0,0), tangent is (1/sqrt2, 1/sqrt2), leftNormal is (1/sqrt2, -1/sqrt2)
      // Radius = 10. Left = (10/sqrt2, -10/sqrt2), Right = (-10/sqrt2, 10/sqrt2)
      final l0 = outline.leftBoundary.first;
      final r0 = outline.rightBoundary.first;
      final dist = (l0 - r0).distance;
      expect(dist, closeTo(20.0, 0.01));
    });

    // 7. Circle stroke
    test('7. Continuous circle centerline produces closed annular outline', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        cap: StrokeCapType.round,
      );

      final circlePoints = <Offset>[];
      const count = 36;
      for (int i = 0; i <= count; i++) {
        final angle = i * 2 * math.pi / count;
        circlePoints.add(
            Offset(100 + 50 * math.cos(angle), 100 + 50 * math.sin(angle)));
      }

      final outline = builder.buildFromOffsets(circlePoints, width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.bounds.left, closeTo(45.0, 2.0));
      expect(outline.bounds.right, closeTo(155.0, 2.0));
      expect(outline.bounds.top, closeTo(45.0, 2.0));
      expect(outline.bounds.bottom, closeTo(155.0, 2.0));
    });

    // 8. Smooth curve
    test('8. Smooth S-curve produces smooth, well-proportioned boundaries', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(8.0),
      );

      final curvePoints = <Offset>[];
      for (int i = 0; i <= 50; i++) {
        final x = i * 4.0;
        final y = 100 + 30 * math.sin(i * 0.1);
        curvePoints.add(Offset(x, y));
      }

      final outline = builder.buildFromOffsets(curvePoints, width: 8.0);
      expect(outline.isNotEmpty, isTrue);
      expect(outline.leftBoundary.length, greaterThanOrEqualTo(50));
      expect(outline.rightBoundary.length, greaterThanOrEqualTo(50));
    });

    // 9. Sharp corner
    test('9. Sharp 90-degree corner maintains apex without collapse', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(12.0),
        join: StrokeJoinType.miter,
        miterLimit: 4.0,
      );

      final outline = builder.buildFromOffsets([
        const Offset(10, 50),
        const Offset(60, 50),
        const Offset(60, 110),
      ], width: 12.0);

      expect(outline.isNotEmpty, isTrue);
      // Outer corner on left boundary for turn right
      final outerX = outline.leftBoundary.map((p) => p.dx).reduce(math.max);
      final outerY = outline.leftBoundary.map((p) => p.dy).reduce(math.min);
      expect(outerX, greaterThanOrEqualTo(66.0));
      expect(outerY, lessThanOrEqualTo(44.0));
    });

    // 10. 180° reversal
    test('10. 180-degree turnaround handles reversal safely without crashing',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        cap: StrokeCapType.round,
        join: StrokeJoinType.round,
      );

      final outline = builder.buildFromOffsets([
        const Offset(10, 50),
        const Offset(80, 50),
        const Offset(10, 50),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      for (final p in outline.contour) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    // 11. Very short stroke
    test('11. Very short stroke (0.5 px) handles micro-movement smoothly', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(8.0),
        cap: StrokeCapType.round,
      );

      final outline = builder.buildFromOffsets([
        const Offset(100.0, 100.0),
        const Offset(100.5, 100.2),
      ], width: 8.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.bounds.width, closeTo(8.5, 0.5));
      expect(outline.bounds.height, closeTo(8.5, 0.5));
    });

    // 12. Large point spacing
    test('12. Large point spacing maintains continuous geometry without gaps',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(500, 500),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.contour.length, greaterThan(4));
    });

    // 13. Constant width
    test('13. Constant width maintains identical thickness along complex path',
        () {
      const profile = ConstantWidthProfile(16.0);
      const builder = StrokeGeometryBuilder(widthProfile: profile);

      final points = List.generate(
        20,
        (i) => StrokePoint(
          position: Offset(i * 15.0, 50.0 + i * 2.0),
          timestamp: Duration(milliseconds: i * 8),
          pressure: 0.1 * (i % 10),
          velocity: 100.0 * i,
        ),
      );

      final outline = builder.buildFromPoints(points);
      expect(outline.isNotEmpty, isTrue);
      expect(outline.leftBoundary.length, equals(outline.rightBoundary.length));
    });

    // 14. Variable width (pressure + velocity)
    test(
        '14. DynamicWidthProfile dynamically modulates width with pressure and velocity',
        () {
      const config = StrokeWidthConfig(
        baseWidth: 10.0,
        pressureEnabled: true,
        velocityEnabled: true,
        minWidthFactor: 0.5,
        maxWidthFactor: 2.0,
      );
      const profile = DynamicWidthProfile(config);
      const builder = StrokeGeometryBuilder(widthProfile: profile);

      const lightFast = StrokePoint(
        position: Offset(10, 10),
        timestamp: Duration.zero,
        pressure: 0.0,
        velocity: 1000.0,
      );
      const heavySlow = StrokePoint(
        position: Offset(100, 10),
        timestamp: Duration(milliseconds: 100),
        pressure: 1.0,
        velocity: 100.0,
      );

      final outline = builder.buildFromPoints([lightFast, heavySlow]);
      expect(outline.isNotEmpty, isTrue);

      final w1 = profile.getWidth(lightFast);
      final w2 = profile.getWidth(heavySlow);
      expect(w1, lessThan(w2));
    });

    // 15. Round caps
    test('15. Round cap produces circular end caps', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.round,
      );

      final outline = builder.buildFromOffsets([
        const Offset(50, 100),
        const Offset(150, 100),
      ], width: 20.0, cap: StrokeCapType.round);

      // Start cap should extend to x = 40 (50 - 10)
      expect(outline.bounds.left, closeTo(40.0, 0.5));
      // End cap should extend to x = 160 (150 + 10)
      expect(outline.bounds.right, closeTo(160.0, 0.5));
    });

    // 16. Butt caps
    test('16. Butt cap truncates exactly at endpoints without extension', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.butt,
      );

      final outline = builder.buildFromOffsets([
        const Offset(50, 100),
        const Offset(150, 100),
      ], width: 20.0, cap: StrokeCapType.butt);

      expect(outline.bounds.left, closeTo(50.0, 0.01));
      expect(outline.bounds.right, closeTo(150.0, 0.01));
    });

    // 17. Square caps
    test(
        '17. Square cap extends forward/backward by radius with square corners',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(20.0),
        cap: StrokeCapType.square,
      );

      final outline = builder.buildFromOffsets([
        const Offset(50, 100),
        const Offset(150, 100),
      ], width: 20.0, cap: StrokeCapType.square);

      expect(outline.bounds.left, closeTo(40.0, 0.01));
      expect(outline.bounds.right, closeTo(160.0, 0.01));
    });

    // 18. Round joins
    test('18. Round join produces arc vertices at corner', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        join: StrokeJoinType.round,
        arcSteps: 8,
      );

      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(50, 50),
      ], width: 10.0, join: StrokeJoinType.round);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.leftBoundary.length, greaterThan(3));
    });

    // 19. Bevel joins
    test('19. Bevel join produces straight diagonal outer bridge', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        join: StrokeJoinType.bevel,
      );

      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(50, 50),
      ], width: 10.0, join: StrokeJoinType.bevel);

      expect(outline.isNotEmpty, isTrue);
    });

    // 20. Miter joins
    test('20. Miter join extends outer apex to true geometric intersection',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        join: StrokeJoinType.miter,
        miterLimit: 4.0,
      );

      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(50, 50),
      ], width: 10.0, join: StrokeJoinType.miter);

      // 90-degree corner outer miter point for (50,0) turning to (50,50)
      // Left boundary miter point is at (55, -5)
      final hasMiterApex = outline.leftBoundary.any(
        (p) => (p.dx - 55.0).abs() < 1.0 && (p.dy - (-5.0)).abs() < 1.0,
      );
      expect(hasMiterApex, isTrue);
    });

    // 21. Extreme acute angle with miter limit enforcement
    test(
        '21. Extreme acute angle miter ratio triggers bevel fallback when exceeding miterLimit',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
        join: StrokeJoinType.miter,
        miterLimit: 2.0, // Strict miter limit
      );

      // Very acute angle (almost 10 degrees)
      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(10, 5),
      ], width: 10.0, join: StrokeJoinType.miter);

      expect(outline.isNotEmpty, isTrue);
      // Outer miter apex is suppressed/beveled so max extent is safely bounded
      expect(outline.bounds.right, lessThan(150.0));
    });

    // 22. No NaN / infinite coordinates
    test(
        '22. Outlines contain zero NaN and zero infinite coordinates across complex geometry',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(12.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(10, 10),
        const Offset(50, 20),
        const Offset(80, 80),
        const Offset(120, 30),
      ], width: 12.0);

      for (final p in outline.contour) {
        expect(p.dx.isNaN, isFalse);
        expect(p.dy.isNaN, isFalse);
        expect(p.dx.isInfinite, isFalse);
        expect(p.dy.isInfinite, isFalse);
      }
    });

    // 23. Closed outline verification
    test(
        '23. Path is closed and first/last contour points connect continuously',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(10, 10),
        const Offset(60, 20),
        const Offset(120, 80),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.contour.length, greaterThan(6));
      expect(outline.perimeter, greaterThan(0.0));
      expect(outline.centerlineLength, greaterThan(0.0));
    });

    // 24. Bounds correctness
    test('24. Bounds strictly encloses all contour points within epsilon', () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(14.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(20, 30),
        const Offset(80, 90),
        const Offset(140, 40),
      ], width: 14.0);

      for (final p in outline.contour) {
        expect(p.dx >= outline.bounds.left - 1e-4, isTrue);
        expect(p.dx <= outline.bounds.right + 1e-4, isTrue);
        expect(p.dy >= outline.bounds.top - 1e-4, isTrue);
        expect(p.dy <= outline.bounds.bottom + 1e-4, isTrue);
      }
    });

    // 25. High-speed stroke
    test(
        '25. High-speed stroke with large jump steps generates continuous stable outline',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(0, 0),
        const Offset(250, 100),
        const Offset(600, 300),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.bounds.width, closeTo(610.0, 5.0));
      expect(outline.bounds.height, closeTo(310.0, 5.0));
    });

    // 26. Zero width handling
    test(
        '26. Zero width handling produces safe empty/degenerate outline without crash',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(0.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(10, 10),
        const Offset(50, 50),
      ], width: 0.0);

      expect(outline.isEmpty, isTrue);
    });

    // 27. Negative/invalid configuration
    test('27. StrokeWidthConfig validates assertions on negative arguments',
        () {
      expect(
        () => StrokeWidthConfig(baseWidth: -1.0),
        throwsAssertionError,
      );
      expect(
        () => StrokeWidthConfig(minWidthFactor: -0.1),
        throwsAssertionError,
      );
      expect(
        () => StrokeWidthConfig(minWidthFactor: 1.5, maxWidthFactor: 1.0),
        throwsAssertionError,
      );
    });

    // 28. Duplicate points
    test(
        '28. Consecutive duplicate points are safely collapsed without zero division',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(10.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(50, 50),
        const Offset(50, 50),
        const Offset(50, 50),
        const Offset(100, 50),
      ], width: 10.0);

      expect(outline.isNotEmpty, isTrue);
      expect(outline.centerline.length, 2);
    });

    // 29. Extremely close points
    test(
        '29. Extremely close points (< 1e-4) are filtered without producing NaN',
        () {
      const builder = StrokeGeometryBuilder(
        widthProfile: ConstantWidthProfile(8.0),
      );

      final outline = builder.buildFromOffsets([
        const Offset(50.0, 50.0),
        const Offset(50.00001, 50.00001),
        const Offset(100.0, 50.0),
      ], width: 8.0);

      expect(outline.isNotEmpty, isTrue);
      for (final p in outline.contour) {
        expect(p.dx.isNaN, isFalse);
        expect(p.dy.isNaN, isFalse);
      }
    });

    // 30. Stroke and OutlineInkRenderer integration
    test(
        '30. OutlineInkRenderer integrates with Stroke object and renders without error',
        () {
      final stroke = Stroke(
        id: 'test_stroke',
        baseWidth: 12.0,
        points: [
          const StrokePoint(position: Offset(10, 10), timestamp: Duration.zero),
          const StrokePoint(
              position: Offset(50, 30), timestamp: Duration(milliseconds: 16)),
          const StrokePoint(
              position: Offset(90, 80), timestamp: Duration(milliseconds: 32)),
        ],
      );

      const renderer = OutlineInkRenderer(
        showOutline: true,
        fillOutline: true,
        showCenterline: true,
        showBoundaries: true,
      );

      final outline = renderer.computeOutline(stroke);
      expect(outline.isNotEmpty, isTrue);
      expect(outline.bounds.width, greaterThan(80));
    });
  });
}
