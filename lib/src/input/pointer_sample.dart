import 'package:flutter/gestures.dart';

/// A high-fidelity snapshot of a raw pointer input event.
///
/// Retains physical touch/stylus hardware metrics (pressure, tilt, orientation,
/// contact radius, device type) rather than discarding them down to a simple Offset.
class PointerSample {
  final Offset position;
  final Duration timestamp;
  final double pressure;
  final double tilt;
  final double orientation;
  final PointerDeviceKind deviceType;
  final int pointerId;
  final double distance;
  final double radiusMajor;
  final double radiusMinor;

  const PointerSample({
    required this.position,
    required this.timestamp,
    this.pressure = 1.0,
    this.tilt = 0.0,
    this.orientation = 0.0,
    this.deviceType = PointerDeviceKind.touch,
    this.pointerId = 0,
    this.distance = 0.0,
    this.radiusMajor = 0.0,
    this.radiusMinor = 0.0,
  });

  /// Extracts full hardware attributes from a Flutter [PointerEvent].
  factory PointerSample.fromPointerEvent(PointerEvent event) {
    return PointerSample(
      position: event.localPosition,
      timestamp: event.timeStamp,
      pressure: event.pressure > 0.0 ? event.pressure : 1.0,
      tilt: event.tilt,
      orientation: event.orientation,
      deviceType: event.kind,
      pointerId: event.pointer,
      distance: event.distance,
      radiusMajor: event.radiusMajor,
      radiusMinor: event.radiusMinor,
    );
  }

  PointerSample copyWith({
    Offset? position,
    Duration? timestamp,
    double? pressure,
    double? tilt,
    double? orientation,
    PointerDeviceKind? deviceType,
    int? pointerId,
    double? distance,
    double? radiusMajor,
    double? radiusMinor,
  }) {
    return PointerSample(
      position: position ?? this.position,
      timestamp: timestamp ?? this.timestamp,
      pressure: pressure ?? this.pressure,
      tilt: tilt ?? this.tilt,
      orientation: orientation ?? this.orientation,
      deviceType: deviceType ?? this.deviceType,
      pointerId: pointerId ?? this.pointerId,
      distance: distance ?? this.distance,
      radiusMajor: radiusMajor ?? this.radiusMajor,
      radiusMinor: radiusMinor ?? this.radiusMinor,
    );
  }

  @override
  String toString() {
    return 'PointerSample(pos: $position, t: $timestamp, p: $pressure, dev: $deviceType, id: $pointerId)';
  }
}
