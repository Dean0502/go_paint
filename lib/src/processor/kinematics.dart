import 'dart:ui';
import '../input/pointer_sample.dart';

/// Tracks motion kinematics, running velocity, and direction vectors
/// with resilience against irregular touch event intervals.
class KinematicsTracker {
  final double maxVelocity;
  final double velocitySmoothingFactor;

  double _smoothedVelocity = 0.0;
  Offset _lastDirection = Offset.zero;

  KinematicsTracker({
    this.maxVelocity = 3000.0, // px per sec
    this.velocitySmoothingFactor = 0.65,
  });

  double get smoothedVelocity => _smoothedVelocity;
  Offset get lastDirection => _lastDirection;

  void reset() {
    _smoothedVelocity = 0.0;
    _lastDirection = Offset.zero;
  }

  /// Calculates velocity and direction between [current] and [previous] samples.
  void update(PointerSample current, PointerSample previous) {
    final dtMicroseconds = (current.timestamp - previous.timestamp).inMicroseconds;
    final dtSeconds = dtMicroseconds / 1e6;

    final displacement = current.position - previous.position;
    final distance = displacement.distance;

    if (distance > 0.001) {
      _lastDirection = Offset(displacement.dx / distance, displacement.dy / distance);
    }

    // Guard against identical timestamps or long pauses (> 100ms)
    if (dtSeconds <= 0.0001 || dtSeconds > 0.15) {
      return;
    }

    final instantVelocity = (distance / dtSeconds).clamp(0.0, maxVelocity);

    if (_smoothedVelocity == 0.0) {
      _smoothedVelocity = instantVelocity;
    } else {
      _smoothedVelocity = velocitySmoothingFactor * instantVelocity +
          (1.0 - velocitySmoothingFactor) * _smoothedVelocity;
    }
  }
}
