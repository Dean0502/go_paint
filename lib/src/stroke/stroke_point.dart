import 'dart:ui';
import '../input/pointer_sample.dart';

/// Represents a smoothed, calibrated point on a continuous stroke.
class StrokePoint {
  final Offset position;
  final Duration timestamp;
  final double pressure;
  final double tilt;
  final double orientation;
  final double width;
  final double velocity;

  const StrokePoint({
    required this.position,
    required this.timestamp,
    this.pressure = 1.0,
    this.tilt = 0.0,
    this.orientation = 0.0,
    this.width = 4.0,
    this.velocity = 0.0,
  });

  /// Creates a [StrokePoint] directly from a [PointerSample] with assigned width and velocity.
  factory StrokePoint.fromSample(
    PointerSample sample, {
    double width = 4.0,
    double velocity = 0.0,
  }) {
    return StrokePoint(
      position: sample.position,
      timestamp: sample.timestamp,
      pressure: sample.pressure,
      tilt: sample.tilt,
      orientation: sample.orientation,
      width: width,
      velocity: velocity,
    );
  }

  StrokePoint copyWith({
    Offset? position,
    Duration? timestamp,
    double? pressure,
    double? tilt,
    double? orientation,
    double? width,
    double? velocity,
  }) {
    return StrokePoint(
      position: position ?? this.position,
      timestamp: timestamp ?? this.timestamp,
      pressure: pressure ?? this.pressure,
      tilt: tilt ?? this.tilt,
      orientation: orientation ?? this.orientation,
      width: width ?? this.width,
      velocity: velocity ?? this.velocity,
    );
  }

  @override
  String toString() => 'StrokePoint(pos: $position, w: $width, p: $pressure)';
}
