import 'dart:math' as math;
import 'dart:ui';
import '../stroke/stroke.dart';
import '../stroke/stroke_point.dart';
import 'geometry_math.dart';
import 'stroke_boundary.dart';
import 'stroke_cap.dart';
import 'stroke_join.dart';
import 'stroke_outline.dart';
import 'stroke_width_profile.dart';

/// Professional stroke geometry builder converting centerlines into continuous closed outlines.
///
/// Features:
/// - Support for constant and dynamic variable width profiles (pressure + velocity)
/// - Geometrically continuous caps (round, butt, square)
/// - Robust joins (round, bevel, miter with configurable miterLimit)
/// - Safe handling of single-tap dots, duplicate points, and sharp corners
/// - Returns an immutable [StrokeOutline] ready for fill rendering, clipping, and GPU masking
class StrokeGeometryBuilder {
  /// Profile governing stroke thickness along the centerline.
  final StrokeWidthProfile widthProfile;

  /// Cap style applied to the stroke endpoints.
  final StrokeCapType cap;

  /// Join style applied to interior stroke vertices.
  final StrokeJoinType join;

  /// Maximum ratio of (miter length / radius) before miter joins fallback to bevel.
  final double miterLimit;

  /// Number of segments used to approximate round arcs.
  final int arcSteps;

  const StrokeGeometryBuilder({
    this.widthProfile = const ConstantWidthProfile(8.0),
    this.cap = StrokeCapType.round,
    this.join = StrokeJoinType.round,
    this.miterLimit = 4.0,
    this.arcSteps = 8,
  }) : assert(miterLimit >= 1.0, 'miterLimit must be >= 1.0'),
       assert(arcSteps >= 2, 'arcSteps must be >= 2');

  /// Builds a [StrokeOutline] from a [Stroke].
  StrokeOutline build(Stroke stroke) {
    return buildFromPoints(stroke.points, baseWidth: stroke.baseWidth);
  }

  /// Builds a [StrokeOutline] from a sequence of [StrokePoint] centerline samples.
  StrokeOutline buildFromPoints(List<StrokePoint> points, {double? baseWidth}) {
    if (points.isEmpty) {
      return StrokeOutline.empty();
    }

    // Filter consecutive duplicate / micro-distance points (< 1e-4 px)
    final filtered = <StrokePoint>[points.first];
    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      if (GeometryMath.distance(filtered.last.position, p.position) >= 1e-4) {
        filtered.add(p);
      }
    }

    // Determine effective width profile
    final profile = (baseWidth != null && widthProfile is ConstantWidthProfile)
        ? ConstantWidthProfile(baseWidth)
        : widthProfile;

    // Extract centerline positions and corresponding radii
    final offsets = <Offset>[];
    final radii = <double>[];

    for (final pt in filtered) {
      offsets.add(pt.position);
      radii.add(profile.getRadius(pt));
    }

    return buildFromOffsetsAndRadii(
      offsets: offsets,
      radii: radii,
    );
  }

  /// Builds a [StrokeOutline] directly from 2D points with optional width, cap, and join overrides.
  StrokeOutline buildFromOffsets(
    List<Offset> offsets, {
    double width = 8.0,
    StrokeCapType? cap,
    StrokeJoinType? join,
  }) {
    if (offsets.isEmpty) return StrokeOutline.empty();

    final filtered = <Offset>[offsets.first];
    for (int i = 1; i < offsets.length; i++) {
      if (GeometryMath.distance(filtered.last, offsets[i]) >= 1e-4) {
        filtered.add(offsets[i]);
      }
    }

    final radius = math.max(0.0, width * 0.5);
    final radii = List<double>.filled(filtered.length, radius);

    final builder = StrokeGeometryBuilder(
      widthProfile: ConstantWidthProfile(width),
      cap: cap ?? this.cap,
      join: join ?? this.join,
      miterLimit: miterLimit,
      arcSteps: arcSteps,
    );

    return builder.buildFromOffsetsAndRadii(
      offsets: filtered,
      radii: radii,
    );
  }

  /// Filters consecutive duplicate or micro-distance points (< 1e-4 px).
  static List<StrokePoint> filterPoints(List<StrokePoint> points) {
    if (points.isEmpty) return const [];
    final filtered = <StrokePoint>[points.first];
    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      if (GeometryMath.distance(filtered.last.position, p.position) >= 1e-4) {
        filtered.add(p);
      }
    }
    return filtered;
  }

  /// Builds a [StrokeOutline] directly from 2D points and explicit per-point radii.
  StrokeOutline buildFromOffsetsAndRadii({
    required List<Offset> offsets,
    required List<double> radii,
  }) {
    if (offsets.isEmpty || radii.every((r) => r <= 0.0)) {
      return StrokeOutline.empty();
    }

    final boundarySeq = StrokeBoundaryGenerator.generate(
      points: offsets,
      radii: radii,
      capType: cap,
      joinType: join,
      miterLimit: miterLimit,
      arcSteps: arcSteps,
    );

    final contour = boundarySeq.closedContour;
    if (contour.isEmpty) return StrokeOutline.empty();

    // Construct the single continuous closed Path
    final path = Path();
    path.moveTo(contour.first.dx, contour.first.dy);
    for (int i = 1; i < contour.length; i++) {
      path.lineTo(contour[i].dx, contour[i].dy);
    }
    path.close();

    // Calculate bounding box from contour vertices
    double minX = contour.first.dx;
    double maxX = contour.first.dx;
    double minY = contour.first.dy;
    double maxY = contour.first.dy;

    for (int i = 1; i < contour.length; i++) {
      final p = contour[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);

    // Calculate centerline length
    double centerlineLen = 0.0;
    for (int i = 0; i < offsets.length - 1; i++) {
      centerlineLen += GeometryMath.distance(offsets[i], offsets[i + 1]);
    }

    // Calculate closed outline perimeter
    double perim = 0.0;
    for (int i = 0; i < contour.length; i++) {
      final next = contour[(i + 1) % contour.length];
      perim += GeometryMath.distance(contour[i], next);
    }

    return StrokeOutline(
      path: path,
      leftBoundary: boundarySeq.leftBoundary,
      rightBoundary: boundarySeq.rightBoundary,
      centerline: offsets,
      contour: contour,
      bounds: bounds,
      centerlineLength: centerlineLen,
      perimeter: perim,
    );
  }
}
