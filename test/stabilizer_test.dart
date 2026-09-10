import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('Stabilizer Tests', () {
    test('Suppresses micro-jitter displacement below threshold', () {
      final stabilizer = Stabilizer(minDistance: 1.5);
      stabilizer.reset();

      const s0 = PointerSample(
        position: Offset(100, 100),
        timestamp: Duration.zero,
        pointerId: 1,
      );
      final initial = stabilizer.addSample(s0);
      expect(initial.length, equals(1));
      expect(initial[0].position, equals(const Offset(100, 100)));

      // Jitter < 1.5px
      const jitterSample = PointerSample(
        position: Offset(100.8, 100.5),
        timestamp: Duration(milliseconds: 8),
        pointerId: 1,
      );
      final jitterResult = stabilizer.addSample(jitterSample);
      expect(jitterResult, isEmpty);

      // Meaningful move > 1.5px
      const moveSample = PointerSample(
        position: Offset(105, 100),
        timestamp: Duration(milliseconds: 16),
        pointerId: 1,
      );
      final moveResult = stabilizer.addSample(moveSample);
      expect(moveResult, isNotEmpty);
    });

    test('Streamline smoothing applies low-pass filter to raw input', () {
      final stabilizer = Stabilizer(streamline: 0.5, minDistance: 0.0);
      stabilizer.reset();

      const s0 = PointerSample(
        position: Offset(0, 0),
        timestamp: Duration.zero,
      );
      stabilizer.addSample(s0);

      // Sharp jump to 100, 100
      const s1 = PointerSample(
        position: Offset(100, 100),
        timestamp: Duration(milliseconds: 16),
      );
      final res = stabilizer.addSample(s1);

      // Because streamline factor is 0.5, the filtered pos is ~ (50, 50),
      // and midpoint with (0,0) produces an interpolated curve point < 100
      expect(res.last.position.dx, lessThan(100.0));
      expect(res.last.position.dy, lessThan(100.0));
    });

    test('Interpolates Catmull-Rom points on high-speed movements', () {
      final stabilizer = Stabilizer(minDistance: 0.0);
      stabilizer.reset();

      // Send 3 initial points
      stabilizer.addSample(const PointerSample(position: Offset(0, 0), timestamp: Duration.zero));
      stabilizer.addSample(const PointerSample(position: Offset(10, 0), timestamp: Duration(milliseconds: 10)));
      stabilizer.addSample(const PointerSample(position: Offset(20, 0), timestamp: Duration(milliseconds: 20)));

      // Fast flick leap > 14px
      final fastPoints = stabilizer.addSample(const PointerSample(
        position: Offset(80, 20),
        timestamp: Duration(milliseconds: 30),
      ));

      // Should contain interpolated Catmull-Rom points + midpoint
      expect(fastPoints.length, greaterThanOrEqualTo(2));
    });
  });
}
