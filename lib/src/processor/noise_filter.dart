import 'dart:ui';
import '../input/pointer_sample.dart';

/// Filters raw pointer noise, tremors, and redundant identical coordinates.
class NoiseFilter {
  final double minDistance;

  NoiseFilter({this.minDistance = 1.5});

  /// Evaluates whether [sample] has sufficient spatial displacement from [lastPosition]
  /// to be considered an intentional user movement rather than resting hand jitter.
  bool accept(PointerSample sample, Offset? lastPosition) {
    if (lastPosition == null) return true;
    final dist = (sample.position - lastPosition).distance;
    return dist >= minDistance;
  }
}
