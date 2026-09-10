import 'dart:math' as math;
import 'dart:ui';
import 'geometry_math.dart';
import 'stroke_cap.dart';
import 'stroke_join.dart';

/// Container for computed left and right boundary point sequences.
class BoundarySequence {
  final List<Offset> leftBoundary;
  final List<Offset> rightBoundary;
  final List<Offset> startCapPoints;
  final List<Offset> endCapPoints;
  final List<Offset> closedContour;

  const BoundarySequence({
    required this.leftBoundary,
    required this.rightBoundary,
    required this.startCapPoints,
    required this.endCapPoints,
    required this.closedContour,
  });
}

/// Generates continuous boundary point sequences with caps and joins.
class StrokeBoundaryGenerator {
  StrokeBoundaryGenerator._();

  /// Generates the complete boundary sequence for a series of centerline points and radii.
  static BoundarySequence generate({
    required List<Offset> points,
    required List<double> radii,
    required StrokeCapType capType,
    required StrokeJoinType joinType,
    double miterLimit = 4.0,
    int arcSteps = 8,
  }) {
    assert(
        points.length == radii.length, 'Points and radii lengths must match');

    if (points.isEmpty) {
      return const BoundarySequence(
        leftBoundary: [],
        rightBoundary: [],
        startCapPoints: [],
        endCapPoints: [],
        closedContour: [],
      );
    }

    // Single-point tap: generate a round, butt, or square dab
    if (points.length == 1) {
      return _generateSinglePointDab(
        center: points[0],
        radius: radii[0],
        capType: capType,
        arcSteps: arcSteps * 2,
      );
    }

    // Compute segment direction vectors
    final segments = <Offset>[];
    for (int i = 0; i < points.length - 1; i++) {
      final diff = points[i + 1] - points[i];
      segments.add(GeometryMath.normalize(diff));
    }

    // Start point offsets and cap
    final vStart = segments.first;
    final nStart = GeometryMath.leftNormal(vStart);
    final r0 = radii.first;
    final l0 = points[0] + nStart * r0;
    final r0Point = points[0] - nStart * r0;

    final startCap = StrokeCapBuilder.buildStartCap(
      center: points[0],
      tangent: vStart,
      l: l0,
      r: r0Point,
      radius: r0,
      capType: capType,
      steps: arcSteps,
    );

    final leftBoundary = <Offset>[l0];
    final rightBoundary = <Offset>[r0Point];

    // Interior vertices (joins)
    for (int i = 1; i < points.length - 1; i++) {
      final vIn = segments[i - 1];
      final vOut = segments[i];
      final r = radii[i];

      final join = StrokeJoinBuilder.buildJoin(
        center: points[i],
        vIn: vIn,
        vOut: vOut,
        radius: r,
        joinType: joinType,
        miterLimit: miterLimit,
        arcSteps: arcSteps,
      );

      leftBoundary.addAll(join.leftPoints);
      rightBoundary.addAll(join.rightPoints);
    }

    // End point offsets and cap
    final vEnd = segments.last;
    final nEnd = GeometryMath.leftNormal(vEnd);
    final rLast = radii.last;
    final lLast = points.last + nEnd * rLast;
    final rLastPoint = points.last - nEnd * rLast;

    leftBoundary.add(lLast);
    rightBoundary.add(rLastPoint);

    final endCap = StrokeCapBuilder.buildEndCap(
      center: points.last,
      tangent: vEnd,
      l: lLast,
      r: rLastPoint,
      radius: rLast,
      capType: capType,
      steps: arcSteps,
    );

    // Assemble continuous closed contour in traversal order:
    // 1. Left boundary forward (L0 -> Ln)
    // 2. End cap forward (Ln -> Rn)
    // 3. Right boundary backward (Rn -> R0)
    // 4. Start cap backward (R0 -> L0)
    final contour = <Offset>[];

    // Left boundary
    for (final p in leftBoundary) {
      _appendPoint(contour, p);
    }

    // End cap
    for (final p in endCap) {
      _appendPoint(contour, p);
    }

    // Right boundary (reversed)
    for (int i = rightBoundary.length - 1; i >= 0; i--) {
      _appendPoint(contour, rightBoundary[i]);
    }

    // Start cap
    for (final p in startCap) {
      _appendPoint(contour, p);
    }

    return BoundarySequence(
      leftBoundary: leftBoundary,
      rightBoundary: rightBoundary,
      startCapPoints: startCap,
      endCapPoints: endCap,
      closedContour: contour,
    );
  }

  static BoundarySequence _generateSinglePointDab({
    required Offset center,
    required double radius,
    required StrokeCapType capType,
    required int arcSteps,
  }) {
    if (radius <= 0) {
      return BoundarySequence(
        leftBoundary: [center],
        rightBoundary: [center],
        startCapPoints: const [],
        endCapPoints: const [],
        closedContour: [center],
      );
    }

    switch (capType) {
      case StrokeCapType.square:
        final r = radius;
        final contour = [
          Offset(center.dx - r, center.dy - r),
          Offset(center.dx + r, center.dy - r),
          Offset(center.dx + r, center.dy + r),
          Offset(center.dx - r, center.dy + r),
        ];
        return BoundarySequence(
          leftBoundary: [contour[0], contour[1]],
          rightBoundary: [contour[3], contour[2]],
          startCapPoints: const [],
          endCapPoints: const [],
          closedContour: contour,
        );

      case StrokeCapType.butt:
      case StrokeCapType.round:
        // Round circle dab
        final contour = <Offset>[];
        final stepAngle = 2 * math.pi / arcSteps;
        for (int i = 0; i < arcSteps; i++) {
          final a = i * stepAngle;
          contour.add(Offset(
            center.dx + radius * math.cos(a),
            center.dy + radius * math.sin(a),
          ));
        }
        final half = arcSteps ~/ 2;
        return BoundarySequence(
          leftBoundary: contour.sublist(0, half + 1),
          rightBoundary: contour.sublist(half).reversed.toList(),
          startCapPoints: const [],
          endCapPoints: const [],
          closedContour: contour,
        );
    }
  }

  static void _appendPoint(List<Offset> list, Offset p) {
    if (list.isEmpty) {
      list.add(p);
      return;
    }
    // Omit duplicate consecutive points to keep contour clean
    final last = list.last;
    if ((p.dx - last.dx).abs() > GeometryMath.epsilon ||
        (p.dy - last.dy).abs() > GeometryMath.epsilon) {
      list.add(p);
    }
  }
}
