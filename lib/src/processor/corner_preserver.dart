import 'dart:math' as math;
import 'dart:ui';
import 'stabilizer_config.dart';

/// Detects sharp direction changes (corners, apexes) and modulates smoothing
/// to preserve sharp features without introducing unnatural bumps.
class CornerPreserver {
  final StabilizerConfig config;
  final double _cosThreshold;

  Offset? _pPrev2;
  Offset? _pPrev1;

  CornerPreserver({required this.config})
      : _cosThreshold = math.cos(config.cornerAngleDeg * math.pi / 180.0);

  void reset() {
    _pPrev2 = null;
    _pPrev1 = null;
  }

  /// Evaluates direction change for new [samplePos].
  ///
  /// Returns a reduced smoothing factor if a strong direction change is detected,
  /// or `null` if the stroke is continuing along a smooth trajectory.
  double? checkDirectionChange(Offset samplePos) {
    if (_pPrev1 == null) {
      _pPrev1 = samplePos;
      return null;
    }

    if (_pPrev2 == null) {
      _pPrev2 = _pPrev1;
      _pPrev1 = samplePos;
      return null;
    }

    // Vector 1: pPrev2 -> pPrev1
    final v1x = _pPrev1!.dx - _pPrev2!.dx;
    final v1y = _pPrev1!.dy - _pPrev2!.dy;
    final d1 = math.sqrt(v1x * v1x + v1y * v1y);

    // Vector 2: pPrev1 -> samplePos
    final v2x = samplePos.dx - _pPrev1!.dx;
    final v2y = samplePos.dy - _pPrev1!.dy;
    final d2 = math.sqrt(v2x * v2x + v2y * v2y);

    _pPrev2 = _pPrev1;
    _pPrev1 = samplePos;

    // If either segment is negligible, cannot reliably compute angle
    if (d1 < 2.0 || d2 < 2.0) {
      return null;
    }

    // Cosine of interior angle
    final cosAngle = (v1x * v2x + v1y * v2y) / (d1 * d2);

    // If cosine is less than threshold, direction turn is sharper than cornerAngleDeg
    if (cosAngle < _cosThreshold) {
      // Return reduced smoothing factor so the curve tracks right through the apex
      return config.cornerSmoothingFactor;
    }

    return null;
  }
}
