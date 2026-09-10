import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('PointerSample Tests', () {
    test('Correctly extracts hardware metrics from PointerDownEvent', () {
      const event = PointerDownEvent(
        pointer: 42,
        position: Offset(120.5, 230.8),
        pressure: 0.75,
        tilt: 0.2,
        orientation: 1.1,
        kind: PointerDeviceKind.stylus,
        radiusMajor: 5.0,
        radiusMinor: 3.0,
      );

      final sample = PointerSample.fromPointerEvent(event);

      expect(sample.pointerId, equals(42));
      expect(sample.position, equals(const Offset(120.5, 230.8)));
      expect(sample.pressure, equals(0.75));
      expect(sample.tilt, equals(0.2));
      expect(sample.orientation, equals(1.1));
      expect(sample.deviceType, equals(PointerDeviceKind.stylus));
      expect(sample.radiusMajor, equals(5.0));
      expect(sample.radiusMinor, equals(3.0));
    });

    test('Defaults pressure to 1.0 when touch device reports 0.0', () {
      const event = PointerDownEvent(
        pointer: 1,
        position: Offset(50, 50),
        pressure: 0.0,
        kind: PointerDeviceKind.touch,
      );

      final sample = PointerSample.fromPointerEvent(event);
      expect(sample.pressure, equals(1.0));
      expect(sample.deviceType, equals(PointerDeviceKind.touch));
    });
  });
}
