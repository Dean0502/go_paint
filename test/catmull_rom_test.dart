import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('CatmullRomSpline Tests', () {
    test('Centripetal evaluation starts near p1 and ends near p2', () {
      const p0 = Offset(0, 0);
      const p1 = Offset(10, 0);
      const p2 = Offset(20, 10);
      const p3 = Offset(30, 10);

      final start = CatmullRomSpline.evaluate(
        p0: p0,
        p1: p1,
        p2: p2,
        p3: p3,
        t: 0.0,
      );
      final end = CatmullRomSpline.evaluate(
        p0: p0,
        p1: p1,
        p2: p2,
        p3: p3,
        t: 1.0,
      );

      expect(start.dx, closeTo(p1.dx, 0.01));
      expect(start.dy, closeTo(p1.dy, 0.01));
      expect(end.dx, closeTo(p2.dx, 0.01));
      expect(end.dy, closeTo(p2.dy, 0.01));
    });

    test('interpolateSegment produces correct step count within convex hull', () {
      const p0 = Offset(0, 0);
      const p1 = Offset(10, 0);
      const p2 = Offset(20, 10);
      const p3 = Offset(30, 10);

      final intermediate = CatmullRomSpline.interpolateSegment(
        p0: p0,
        p1: p1,
        p2: p2,
        p3: p3,
        steps: 3,
      );

      expect(intermediate.length, equals(3));
      for (final pt in intermediate) {
        expect(pt.dx, greaterThanOrEqualTo(10.0));
        expect(pt.dx, lessThanOrEqualTo(20.0));
      }
    });
  });
}
