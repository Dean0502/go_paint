import 'dart:ui';
import 'package:flutter/gestures.dart';

/// Real-time diagnostics snapshot for telemetry HUD and visual debug overlays.
class StrokeDiagnostics {
  /// Unmodified raw hardware coordinates directly from the touch digitizer.
  final List<Offset> rawPoints;

  /// Stabilized and smoothed centerline points.
  final List<Offset> stabilizedPoints;

  /// Intermediate curve points synthesized by Catmull-Rom spline interpolation.
  final List<Offset> catmullPoints;

  /// Transient 1-frame forward predicted fingertip position (null if disabled/inactive).
  final Offset? predictedTip;

  /// Current smoothed velocity in logical pixels per second.
  final double currentVelocity;

  /// Current stroke pressure (0.0 to 1.0).
  final double currentPressure;

  /// Detected hardware pointer device kind (stylus, touch, mouse).
  final PointerDeviceKind deviceKind;

  /// Count of active concurrent touch pointers.
  final int activePointerCount;

  /// Detected corner apex in raw hardware space (null if no corner detected).
  final Offset? rawApex;

  /// Corresponding apex position on the processed path.
  final Offset? processedApex;

  const StrokeDiagnostics({
    this.rawPoints = const [],
    this.stabilizedPoints = const [],
    this.catmullPoints = const [],
    this.predictedTip,
    this.currentVelocity = 0.0,
    this.currentPressure = 1.0,
    this.deviceKind = PointerDeviceKind.touch,
    this.activePointerCount = 0,
    this.rawApex,
    this.processedApex,
  });
}
