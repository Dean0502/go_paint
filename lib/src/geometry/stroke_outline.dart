import 'dart:ui';

/// Represents a continuous, closed 2D geometric outline of a stroke.
///
/// Contains the single closed [Path], the discrete [leftBoundary] and [rightBoundary]
/// point sequences, and the complete [contour] in traversal order.
class StrokeOutline {
  /// The single continuous closed path for filling, clipping, and rendering.
  final Path path;

  /// The ordered points along the left boundary from start to end.
  final List<Offset> leftBoundary;

  /// The ordered points along the right boundary from start to end.
  final List<Offset> rightBoundary;

  /// The ordered centerline points from which this outline was constructed.
  final List<Offset> centerline;

  /// Complete sequence of vertices forming the closed outer contour in traversal order:
  /// (Start cap -> Left boundary -> End cap -> Right boundary in reverse -> Close).
  final List<Offset> contour;

  /// The axis-aligned bounding box enclosing the entire stroke outline.
  final Rect bounds;

  /// Total arc length of the stroke centerline.
  final double centerlineLength;

  /// Total perimeter of the closed contour.
  final double perimeter;

  const StrokeOutline({
    required this.path,
    required this.leftBoundary,
    required this.rightBoundary,
    required this.centerline,
    required this.contour,
    required this.bounds,
    required this.centerlineLength,
    required this.perimeter,
  });

  /// An empty stroke outline.
  factory StrokeOutline.empty() {
    return StrokeOutline(
      path: Path(),
      leftBoundary: const [],
      rightBoundary: const [],
      centerline: const [],
      contour: const [],
      bounds: Rect.zero,
      centerlineLength: 0.0,
      perimeter: 0.0,
    );
  }

  /// Whether this outline contains no geometry.
  bool get isEmpty => contour.isEmpty;

  /// Whether this outline contains geometry.
  bool get isNotEmpty => contour.isNotEmpty;

  /// Checks whether a 2D point lies within the closed outline.
  bool contains(Offset point) => path.contains(point);
}
