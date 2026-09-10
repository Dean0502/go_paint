import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import '../input/pointer_sample.dart';

/// Contract for resolving stroke pressure from hardware sensors or kinematic simulation.
abstract class PressureSource {
  const PressureSource();

  double resolve(
    PointerSample sample, {
    double velocity = 0.0,
    double maxVelocity = 3000.0,
  });
}

/// Directly queries hardware pressure metrics (e.g. Apple Pencil, S-Pen, active Wacom stylus).
class HardwarePressureSource extends PressureSource {
  final double pressureGamma;

  const HardwarePressureSource({this.pressureGamma = 1.0});

  @override
  double resolve(
    PointerSample sample, {
    double velocity = 0.0,
    double maxVelocity = 3000.0,
  }) {
    final raw = sample.pressure.clamp(0.0, 1.0);
    if (pressureGamma == 1.0 || raw <= 0.0) return raw;
    return math.pow(raw, pressureGamma).toDouble().clamp(0.05, 1.0);
  }
}

/// Generates simulated tactile pressure based on motion kinematics.
///
/// Slow movements yield higher pressure (richer deposition); fast flicks yield lower pressure.
class SimulatedPressureSource extends PressureSource {
  final double minPressure;
  final double maxPressure;
  final double velocityExponent;

  const SimulatedPressureSource({
    this.minPressure = 0.25,
    this.maxPressure = 1.0,
    this.velocityExponent = 0.6,
  });

  @override
  double resolve(
    PointerSample sample, {
    double velocity = 0.0,
    double maxVelocity = 3000.0,
  }) {
    if (maxVelocity <= 0.0) return maxPressure;
    final normV = (velocity / maxVelocity).clamp(0.0, 1.0);
    final simulated = maxPressure - math.pow(normV, velocityExponent) * (maxPressure - minPressure);
    return simulated.clamp(minPressure, maxPressure);
  }
}

/// Intelligently switches between hardware pressure and velocity-based simulation.
class AdaptivePressureSource extends PressureSource {
  final HardwarePressureSource hardwareSource;
  final SimulatedPressureSource simulatedSource;

  const AdaptivePressureSource({
    this.hardwareSource = const HardwarePressureSource(),
    this.simulatedSource = const SimulatedPressureSource(),
  });

  @override
  double resolve(
    PointerSample sample, {
    double velocity = 0.0,
    double maxVelocity = 3000.0,
  }) {
    final isStylus = sample.deviceType == PointerDeviceKind.stylus ||
        sample.deviceType == PointerDeviceKind.invertedStylus;

    // Use hardware pressure if stylus device has reported valid varied pressure
    if (isStylus && sample.pressure > 0.0 && sample.pressure < 1.0) {
      return hardwareSource.resolve(sample, velocity: velocity, maxVelocity: maxVelocity);
    }

    // Otherwise use calibrated kinematic simulation
    return simulatedSource.resolve(sample, velocity: velocity, maxVelocity: maxVelocity);
  }
}
