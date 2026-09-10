import 'dart:math' as math;
import 'dart:ui';

/// Comprehensive geometric analysis comparing raw hardware touch input against
/// the processed/stabilized stroke path.
class StrokeGeometryReport {
  /// Maximum orthogonal distance from any raw point to the processed polyline (in logical px).
  final double maxDeviationPx;

  /// Average orthogonal distance from raw points to the processed polyline (in logical px).
  final double averageDeviationPx;

  /// Root-Mean-Square orthogonal deviation from raw points to the processed polyline (in logical px).
  final double rmsDeviationPx;

  /// Maximum displacement between corresponding points or peak point-to-path deviation.
  final double maxDisplacementPx;

  /// Average displacement across all evaluated points.
  final double averageDisplacementPx;

  /// Cumulative arc length of the raw hardware path (in logical px).
  final double rawPathLength;

  /// Cumulative arc length of the processed/stabilized path (in logical px).
  final double processedPathLength;

  /// Total straight-line displacement of the processed path: distance(first, last).
  final double totalProcessedDisplacement;

  /// Maximum point-to-path deviation (alias/synonym for maxDeviationPx).
  final double maxRawToProcessedDeviation;

  /// Axis-aligned bounding box of raw touch coordinates.
  final Rect rawBounds;

  /// Axis-aligned bounding box of processed stroke coordinates.
  final Rect processedBounds;

  /// Corner apex analysis for sharp directional changes.
  final CornerAnalysisResult corner;

  /// Straight-line regression analysis (calculated for all strokes, primary for long_straight_line).
  final StraightLineAnalysisResult? straightLine;

  /// Circle fit analysis (calculated when points indicate circular curvature).
  final CircleAnalysisResult? circle;

  const StrokeGeometryReport({
    required this.maxDeviationPx,
    required this.averageDeviationPx,
    required this.rmsDeviationPx,
    required this.maxDisplacementPx,
    required this.averageDisplacementPx,
    required this.rawPathLength,
    required this.processedPathLength,
    required this.totalProcessedDisplacement,
    required this.maxRawToProcessedDeviation,
    required this.rawBounds,
    required this.processedBounds,
    required this.corner,
    this.straightLine,
    this.circle,
  });

  /// Serializes report to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'maxDeviationPx': _round(maxDeviationPx),
      'averageDeviationPx': _round(averageDeviationPx),
      'rmsDeviationPx': _round(rmsDeviationPx),
      'maxDisplacementPx': _round(maxDisplacementPx),
      'averageDisplacementPx': _round(averageDisplacementPx),
      'rawPathLength': _round(rawPathLength),
      'processedPathLength': _round(processedPathLength),
      'totalProcessedDisplacement': _round(totalProcessedDisplacement),
      'maxRawToProcessedDeviation': _round(maxRawToProcessedDeviation),
      'rawBounds': {
        'left': _round(rawBounds.left),
        'top': _round(rawBounds.top),
        'width': _round(rawBounds.width),
        'height': _round(rawBounds.height),
      },
      'processedBounds': {
        'left': _round(processedBounds.left),
        'top': _round(processedBounds.top),
        'width': _round(processedBounds.width),
        'height': _round(processedBounds.height),
      },
      'corner': corner.toJson(),
      if (straightLine != null) 'straightLine': straightLine!.toJson(),
      if (circle != null) 'circle': circle!.toJson(),
    };
  }

  static double _round(double val, [int decimals = 2]) =>
      double.parse(val.toStringAsFixed(decimals));

  factory StrokeGeometryReport.fromJson(Map<String, dynamic> json) {
    return StrokeGeometryReport(
      maxDeviationPx: (json['maxDeviationPx'] as num?)?.toDouble() ?? 0.0,
      averageDeviationPx: (json['averageDeviationPx'] as num?)?.toDouble() ?? 0.0,
      rmsDeviationPx: (json['rmsDeviationPx'] as num?)?.toDouble() ?? 0.0,
      maxDisplacementPx: (json['maxDisplacementPx'] as num?)?.toDouble() ?? 0.0,
      averageDisplacementPx: (json['averageDisplacementPx'] as num?)?.toDouble() ?? 0.0,
      rawPathLength: (json['rawPathLength'] as num?)?.toDouble() ?? 0.0,
      processedPathLength: (json['processedPathLength'] as num?)?.toDouble() ?? 0.0,
      totalProcessedDisplacement: (json['totalProcessedDisplacement'] as num?)?.toDouble() ?? 0.0,
      maxRawToProcessedDeviation: (json['maxRawToProcessedDeviation'] as num?)?.toDouble() ?? 0.0,
      rawBounds: json['rawBounds'] != null
          ? Rect.fromLTWH(
              (json['rawBounds']['left'] as num).toDouble(),
              (json['rawBounds']['top'] as num).toDouble(),
              (json['rawBounds']['width'] as num).toDouble(),
              (json['rawBounds']['height'] as num).toDouble(),
            )
          : Rect.zero,
      processedBounds: json['processedBounds'] != null
          ? Rect.fromLTWH(
              (json['processedBounds']['left'] as num).toDouble(),
              (json['processedBounds']['top'] as num).toDouble(),
              (json['processedBounds']['width'] as num).toDouble(),
              (json['processedBounds']['height'] as num).toDouble(),
            )
          : Rect.zero,
      corner: json['corner'] != null
          ? CornerAnalysisResult.fromJson(json['corner'] as Map<String, dynamic>)
          : const CornerAnalysisResult(detected: false),
      straightLine: json['straightLine'] != null
          ? StraightLineAnalysisResult.fromJson(json['straightLine'] as Map<String, dynamic>)
          : null,
      circle: json['circle'] != null
          ? CircleAnalysisResult.fromJson(json['circle'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Detailed geometry analysis of detected corner/apex features.
class CornerAnalysisResult {
  /// Whether a genuine corner apex was detected along the stroke trajectory.
  final bool detected;

  /// Coordinates of the raw hardware apex.
  final Offset? rawApex;

  /// Corresponding projected position on the processed path.
  final Offset? processedApex;

  /// Distance from the raw apex to the processed stroke (in logical px).
  final double? apexDeviationPx;

  /// Maximum point-to-path deviation in the neighborhood around the corner.
  final double? maxCornerDeviationPx;

  /// Normalized direction vector entering the corner apex.
  final Offset? incomingDirection;

  /// Normalized direction vector leaving the corner apex.
  final Offset? outgoingDirection;

  /// Direction turn angle in degrees (e.g. 90° for right angle, 180° for hairpin turn).
  final double? detectedAngleDeg;

  const CornerAnalysisResult({
    required this.detected,
    this.rawApex,
    this.processedApex,
    this.apexDeviationPx,
    this.maxCornerDeviationPx,
    this.incomingDirection,
    this.outgoingDirection,
    this.detectedAngleDeg,
  });

  Map<String, dynamic> toJson() {
    if (!detected) {
      return {'detected': false};
    }
    return {
      'detected': true,
      if (rawApex != null) 'rawApex': {'x': _round(rawApex!.dx), 'y': _round(rawApex!.dy)},
      if (processedApex != null)
        'processedApex': {'x': _round(processedApex!.dx), 'y': _round(processedApex!.dy)},
      if (apexDeviationPx != null) 'apexDeviationPx': _round(apexDeviationPx!),
      if (maxCornerDeviationPx != null) 'maxCornerDeviationPx': _round(maxCornerDeviationPx!),
      if (incomingDirection != null)
        'incomingDirection': {
          'dx': _round(incomingDirection!.dx, 3),
          'dy': _round(incomingDirection!.dy, 3),
        },
      if (outgoingDirection != null)
        'outgoingDirection': {
          'dx': _round(outgoingDirection!.dx, 3),
          'dy': _round(outgoingDirection!.dy, 3),
        },
      if (detectedAngleDeg != null) 'detectedAngleDeg': _round(detectedAngleDeg!, 1),
    };
  }

  static double _round(double val, [int decimals = 2]) =>
      double.parse(val.toStringAsFixed(decimals));

  factory CornerAnalysisResult.fromJson(Map<String, dynamic> json) {
    final detected = json['detected'] as bool? ?? false;
    if (!detected) {
      return const CornerAnalysisResult(detected: false);
    }
    return CornerAnalysisResult(
      detected: true,
      rawApex: json['rawApex'] != null
          ? Offset(
              (json['rawApex']['x'] as num).toDouble(),
              (json['rawApex']['y'] as num).toDouble(),
            )
          : null,
      processedApex: json['processedApex'] != null
          ? Offset(
              (json['processedApex']['x'] as num).toDouble(),
              (json['processedApex']['y'] as num).toDouble(),
            )
          : null,
      apexDeviationPx: (json['apexDeviationPx'] as num?)?.toDouble(),
      maxCornerDeviationPx: (json['maxCornerDeviationPx'] as num?)?.toDouble(),
      incomingDirection: json['incomingDirection'] != null
          ? Offset(
              (json['incomingDirection']['dx'] as num).toDouble(),
              (json['incomingDirection']['dy'] as num).toDouble(),
            )
          : null,
      outgoingDirection: json['outgoingDirection'] != null
          ? Offset(
              (json['outgoingDirection']['dx'] as num).toDouble(),
              (json['outgoingDirection']['dy'] as num).toDouble(),
            )
          : null,
      detectedAngleDeg: (json['detectedAngleDeg'] as num?)?.toDouble(),
    );
  }
}

/// Analysis for straight line strokes using Total Least Squares orthogonal regression.
class StraightLineAnalysisResult {
  /// Maximum perpendicular distance of raw points to the best-fit line.
  final double maxDeviationPx;

  /// Average perpendicular distance of raw points to the best-fit line.
  final double averageDeviationPx;

  /// Root-Mean-Square perpendicular distance of raw points to the best-fit line.
  final double rmsDeviationPx;

  /// Maximum perpendicular distance of processed points to the raw best-fit line.
  final double processedMaxDeviationPx;

  /// Average perpendicular distance of processed points to the raw best-fit line.
  final double processedAvgDeviationPx;

  /// Angle of the best-fit line in degrees relative to the horizontal axis [0, 180).
  final double lineAngleDeg;

  const StraightLineAnalysisResult({
    required this.maxDeviationPx,
    required this.averageDeviationPx,
    required this.rmsDeviationPx,
    required this.processedMaxDeviationPx,
    required this.processedAvgDeviationPx,
    required this.lineAngleDeg,
  });

  Map<String, dynamic> toJson() {
    return {
      'maxDeviationPx': _round(maxDeviationPx),
      'averageDeviationPx': _round(averageDeviationPx),
      'rmsDeviationPx': _round(rmsDeviationPx),
      'processedMaxDeviationPx': _round(processedMaxDeviationPx),
      'processedAvgDeviationPx': _round(processedAvgDeviationPx),
      'lineAngleDeg': _round(lineAngleDeg, 1),
    };
  }

  static double _round(double val, [int decimals = 2]) =>
      double.parse(val.toStringAsFixed(decimals));

  factory StraightLineAnalysisResult.fromJson(Map<String, dynamic> json) {
    return StraightLineAnalysisResult(
      maxDeviationPx: (json['maxDeviationPx'] as num?)?.toDouble() ?? 0.0,
      averageDeviationPx: (json['averageDeviationPx'] as num?)?.toDouble() ?? 0.0,
      rmsDeviationPx: (json['rmsDeviationPx'] as num?)?.toDouble() ?? 0.0,
      processedMaxDeviationPx: (json['processedMaxDeviationPx'] as num?)?.toDouble() ?? 0.0,
      processedAvgDeviationPx: (json['processedAvgDeviationPx'] as num?)?.toDouble() ?? 0.0,
      lineAngleDeg: (json['lineAngleDeg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Circle fit analysis using Kåsa algebraic circle fitting.
class CircleAnalysisResult {
  /// Center of the fitted circle in logical pixels.
  final Offset fittedCenter;

  /// Radius of the fitted circle in logical pixels.
  final double fittedRadius;

  /// Standard deviation of raw point radial distances to the fitted circle.
  final double radiusVariation;

  /// Maximum absolute radial error (|r_i - R|) of raw points.
  final double maxRadialErrorPx;

  /// Average absolute radial error of raw points.
  final double averageRadialErrorPx;

  /// Maximum absolute radial error of processed points against the fitted circle.
  final double processedMaxRadialErrorPx;

  /// Average absolute radial error of processed points against the fitted circle.
  final double processedAvgRadialErrorPx;

  const CircleAnalysisResult({
    required this.fittedCenter,
    required this.fittedRadius,
    required this.radiusVariation,
    required this.maxRadialErrorPx,
    required this.averageRadialErrorPx,
    required this.processedMaxRadialErrorPx,
    required this.processedAvgRadialErrorPx,
  });

  Map<String, dynamic> toJson() {
    return {
      'fittedCenter': {'x': _round(fittedCenter.dx), 'y': _round(fittedCenter.dy)},
      'fittedRadius': _round(fittedRadius),
      'radiusVariation': _round(radiusVariation),
      'maxRadialErrorPx': _round(maxRadialErrorPx),
      'averageRadialErrorPx': _round(averageRadialErrorPx),
      'processedMaxRadialErrorPx': _round(processedMaxRadialErrorPx),
      'processedAvgRadialErrorPx': _round(processedAvgRadialErrorPx),
    };
  }

  static double _round(double val, [int decimals = 2]) =>
      double.parse(val.toStringAsFixed(decimals));

  factory CircleAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CircleAnalysisResult(
      fittedCenter: json['fittedCenter'] != null
          ? Offset(
              (json['fittedCenter']['x'] as num).toDouble(),
              (json['fittedCenter']['y'] as num).toDouble(),
            )
          : Offset.zero,
      fittedRadius: (json['fittedRadius'] as num?)?.toDouble() ?? 0.0,
      radiusVariation: (json['radiusVariation'] as num?)?.toDouble() ?? 0.0,
      maxRadialErrorPx: (json['maxRadialErrorPx'] as num?)?.toDouble() ?? 0.0,
      averageRadialErrorPx: (json['averageRadialErrorPx'] as num?)?.toDouble() ?? 0.0,
      processedMaxRadialErrorPx: (json['processedMaxRadialErrorPx'] as num?)?.toDouble() ?? 0.0,
      processedAvgRadialErrorPx: (json['processedAvgRadialErrorPx'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Helper container for point-to-polyline projection results.
class PointPolylineProjection {
  final double distance;
  final Offset projectedPoint;

  const PointPolylineProjection(this.distance, this.projectedPoint);
}

/// Core geometric analysis engine comparing raw touch inputs with processed stroke output.
class StrokeGeometryAnalyzer {
  /// Computes comprehensive geometric comparisons between raw touch points
  /// and processed stroke points in logical Flutter coordinates.
  static StrokeGeometryReport analyze(
    List<Offset> rawPoints,
    List<Offset> processedPoints, {
    String? testMode,
  }) {
    if (rawPoints.isEmpty || processedPoints.isEmpty) {
      return const StrokeGeometryReport(
        maxDeviationPx: 0.0,
        averageDeviationPx: 0.0,
        rmsDeviationPx: 0.0,
        maxDisplacementPx: 0.0,
        averageDisplacementPx: 0.0,
        rawPathLength: 0.0,
        processedPathLength: 0.0,
        totalProcessedDisplacement: 0.0,
        maxRawToProcessedDeviation: 0.0,
        rawBounds: Rect.zero,
        processedBounds: Rect.zero,
        corner: CornerAnalysisResult(detected: false),
      );
    }

    // 1. Calculate path bounds
    final rawBounds = _computeBounds(rawPoints);
    final processedBounds = _computeBounds(processedPoints);

    // 2. Calculate cumulative path lengths
    final rawPathLength = _computePathLength(rawPoints);
    final processedPathLength = _computePathLength(processedPoints);
    final totalProcessedDisplacement =
        (processedPoints.last - processedPoints.first).distance;

    // 3. Measure orthogonal point-to-path deviations from each raw point
    double sumDist = 0.0;
    double sumDistSq = 0.0;
    double maxDist = 0.0;
    final deviations = List<double>.filled(rawPoints.length, 0.0);

    for (int i = 0; i < rawPoints.length; i++) {
      final proj = projectPointToPolyline(rawPoints[i], processedPoints);
      deviations[i] = proj.distance;
      sumDist += proj.distance;
      sumDistSq += proj.distance * proj.distance;
      if (proj.distance > maxDist) {
        maxDist = proj.distance;
      }
    }

    final avgDist = sumDist / rawPoints.length;
    final rmsDist = math.sqrt(sumDistSq / rawPoints.length);

    // 4. Corner apex analysis
    final cornerResult = _analyzeCorner(rawPoints, processedPoints, deviations);

    // 5. Straight-line regression analysis
    final straightLineResult = _analyzeStraightLine(rawPoints, processedPoints);

    // 6. Circle fitting analysis
    final circleResult = _analyzeCircle(rawPoints, processedPoints);

    return StrokeGeometryReport(
      maxDeviationPx: maxDist,
      averageDeviationPx: avgDist,
      rmsDeviationPx: rmsDist,
      maxDisplacementPx: maxDist,
      averageDisplacementPx: avgDist,
      rawPathLength: rawPathLength,
      processedPathLength: processedPathLength,
      totalProcessedDisplacement: totalProcessedDisplacement,
      maxRawToProcessedDeviation: maxDist,
      rawBounds: rawBounds,
      processedBounds: processedBounds,
      corner: cornerResult,
      straightLine: straightLineResult,
      circle: circleResult,
    );
  }

  /// Calculates bounding box for a point sequence.
  static Rect _computeBounds(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Computes cumulative arc length of a polyline.
  static double _computePathLength(List<Offset> points) {
    if (points.length < 2) return 0.0;
    double length = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      length += (points[i + 1] - points[i]).distance;
    }
    return length;
  }

  /// Calculates orthogonal projection of point [p] onto segment [a] - [b].
  static PointPolylineProjection projectPointToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq < 1e-6) {
      return PointPolylineProjection((p - a).distance, a);
    }
    final t = math.max(0.0, math.min(1.0, ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq));
    final proj = Offset(a.dx + t * dx, a.dy + t * dy);
    return PointPolylineProjection((p - proj).distance, proj);
  }

  /// Finds minimum orthogonal distance and closest point on a polyline from point [p].
  static PointPolylineProjection projectPointToPolyline(Offset p, List<Offset> polyline) {
    if (polyline.isEmpty) return PointPolylineProjection(0.0, p);
    if (polyline.length == 1) {
      return PointPolylineProjection((p - polyline.first).distance, polyline.first);
    }

    double minDist = double.infinity;
    Offset bestProj = polyline.first;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];

      // Bounding box cull
      final minX = math.min(a.dx, b.dx) - minDist;
      final maxX = math.max(a.dx, b.dx) + minDist;
      final minY = math.min(a.dy, b.dy) - minDist;
      final maxY = math.max(a.dy, b.dy) + minDist;

      if (p.dx < minX || p.dx > maxX || p.dy < minY || p.dy > maxY) {
        continue;
      }

      final res = projectPointToSegment(p, a, b);
      if (res.distance < minDist) {
        minDist = res.distance;
        bestProj = res.projectedPoint;
        if (minDist < 0.0001) break;
      }
    }
    return PointPolylineProjection(minDist, bestProj);
  }

  /// Evaluates whether the stroke contains a detectable corner apex,
  /// and calculates apex displacement and directional metrics.
  static CornerAnalysisResult _analyzeCorner(
    List<Offset> raw,
    List<Offset> processed,
    List<double> deviations,
  ) {
    if (raw.length < 5) {
      return const CornerAnalysisResult(detected: false);
    }

    const chordLenPx = 12.0;
    final turnAngles = List<double>.filled(raw.length, 0.0);
    final inVectors = List<Offset>.filled(raw.length, Offset.zero);
    final outVectors = List<Offset>.filled(raw.length, Offset.zero);

    for (int i = 1; i < raw.length - 1; i++) {
      // Look backwards until chord distance >= chordLenPx
      int prevIdx = i - 1;
      double distBack = (raw[i] - raw[prevIdx]).distance;
      while (prevIdx > 0 && distBack < chordLenPx) {
        prevIdx--;
        distBack = (raw[i] - raw[prevIdx]).distance;
      }

      // Look forwards until chord distance >= chordLenPx
      int nextIdx = i + 1;
      double distFwd = (raw[nextIdx] - raw[i]).distance;
      while (nextIdx < raw.length - 1 && distFwd < chordLenPx) {
        nextIdx++;
        distFwd = (raw[nextIdx] - raw[i]).distance;
      }

      final v1 = raw[i] - raw[prevIdx];
      final v2 = raw[nextIdx] - raw[i];
      final d1 = v1.distance;
      final d2 = v2.distance;

      if (d1 >= 2.0 && d2 >= 2.0) {
        final cosVal = ((v1.dx * v2.dx) + (v1.dy * v2.dy)) / (d1 * d2);
        final clampedCos = math.max(-1.0, math.min(1.0, cosVal));
        final angleDeg = math.acos(clampedCos) * 180.0 / math.pi;

        turnAngles[i] = angleDeg;
        inVectors[i] = Offset(v1.dx / d1, v1.dy / d1);
        outVectors[i] = Offset(v2.dx / d2, v2.dy / d2);
      }
    }

    // Find local peaks with turn angle >= 35°
    int bestApexIdx = -1;
    double maxApexAngle = 0.0;

    for (int i = 2; i < raw.length - 2; i++) {
      final angle = turnAngles[i];
      if (angle >= 35.0) {
        final isLocalMax = angle >= turnAngles[i - 1] &&
            angle >= turnAngles[i - 2] &&
            angle >= turnAngles[i + 1] &&
            angle >= turnAngles[i + 2];

        if (isLocalMax && angle > maxApexAngle) {
          maxApexAngle = angle;
          bestApexIdx = i;
        }
      }
    }

    // If no distinct corner apex is found, return detected: false
    if (bestApexIdx < 0) {
      return const CornerAnalysisResult(detected: false);
    }

    final rawApex = raw[bestApexIdx];
    final proj = projectPointToPolyline(rawApex, processed);
    final apexDev = proj.distance;
    final processedApex = proj.projectedPoint;

    // Calculate maximum deviation in the neighborhood of the corner (within 15px)
    double maxCornerDev = apexDev;
    for (int i = 0; i < raw.length; i++) {
      if ((raw[i] - rawApex).distance <= 15.0) {
        if (deviations[i] > maxCornerDev) {
          maxCornerDev = deviations[i];
        }
      }
    }

    return CornerAnalysisResult(
      detected: true,
      rawApex: rawApex,
      processedApex: processedApex,
      apexDeviationPx: apexDev,
      maxCornerDeviationPx: maxCornerDev,
      incomingDirection: inVectors[bestApexIdx],
      outgoingDirection: outVectors[bestApexIdx],
      detectedAngleDeg: maxApexAngle,
    );
  }

  /// Evaluates best-fit straight line using Total Least Squares (orthogonal distance regression).
  static StraightLineAnalysisResult? _analyzeStraightLine(
    List<Offset> raw,
    List<Offset> processed,
  ) {
    if (raw.length < 3) return null;

    final n = raw.length;
    double meanX = 0.0;
    double meanY = 0.0;

    for (final p in raw) {
      meanX += p.dx;
      meanY += p.dy;
    }
    meanX /= n;
    meanY /= n;

    double sxx = 0.0;
    double syy = 0.0;
    double sxy = 0.0;

    for (final p in raw) {
      final dx = p.dx - meanX;
      final dy = p.dy - meanY;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }

    // Check if points are virtually a single dot
    if (sxx + syy < 1e-4) return null;

    // Best-fit orientation angle
    final phi = 0.5 * math.atan2(2.0 * sxy, sxx - syy);
    // Normal vector to the line
    final nx = -math.sin(phi);
    final ny = math.cos(phi);

    double sumDist = 0.0;
    double sumDistSq = 0.0;
    double maxDist = 0.0;

    for (final p in raw) {
      final d = ((p.dx - meanX) * nx + (p.dy - meanY) * ny).abs();
      sumDist += d;
      sumDistSq += d * d;
      if (d > maxDist) maxDist = d;
    }

    final avgDist = sumDist / n;
    final rmsDist = math.sqrt(sumDistSq / n);

    // Processed points against the raw best-fit line
    double procMaxDist = 0.0;
    double procSumDist = 0.0;

    for (final p in processed) {
      final d = ((p.dx - meanX) * nx + (p.dy - meanY) * ny).abs();
      procSumDist += d;
      if (d > procMaxDist) procMaxDist = d;
    }
    final procAvgDist = processed.isNotEmpty ? procSumDist / processed.length : 0.0;

    var angleDeg = phi * 180.0 / math.pi;
    if (angleDeg < 0.0) angleDeg += 180.0;

    return StraightLineAnalysisResult(
      maxDeviationPx: maxDist,
      averageDeviationPx: avgDist,
      rmsDeviationPx: rmsDist,
      processedMaxDeviationPx: procMaxDist,
      processedAvgDeviationPx: procAvgDist,
      lineAngleDeg: angleDeg,
    );
  }

  /// Fits a circle using Kåsa algebraic method.
  static CircleAnalysisResult? _analyzeCircle(
    List<Offset> raw,
    List<Offset> processed,
  ) {
    if (raw.length < 5) return null;

    final n = raw.length;
    double sumX = 0.0;
    double sumY = 0.0;
    double sumX2 = 0.0;
    double sumY2 = 0.0;
    double sumXY = 0.0;
    double sumX3 = 0.0;
    double sumY3 = 0.0;
    double sumXY2 = 0.0;
    double sumX2Y = 0.0;

    for (final p in raw) {
      final x = p.dx;
      final y = p.dy;
      final x2 = x * x;
      final y2 = y * y;
      sumX += x;
      sumY += y;
      sumX2 += x2;
      sumY2 += y2;
      sumXY += x * y;
      sumX3 += x2 * x;
      sumY3 += y2 * y;
      sumXY2 += x * y2;
      sumX2Y += x2 * y;
    }

    final c1 = sumX3 + sumXY2;
    final c2 = sumX2Y + sumY3;

    // Build 2x2 system for center (xc, yc):
    // A11 * xc + A12 * yc = B1
    // A21 * xc + A22 * yc = B2
    final a11 = 2.0 * (sumX2 - (sumX * sumX) / n);
    final a12 = 2.0 * (sumXY - (sumX * sumY) / n);
    final b1 = c1 - (sumX * (sumX2 + sumY2)) / n;

    final a21 = a12;
    final a22 = 2.0 * (sumY2 - (sumY * sumY) / n);
    final b2 = c2 - (sumY * (sumX2 + sumY2)) / n;

    final det = a11 * a22 - a12 * a21;
    if (det.abs() < 1e-5) return null; // Collinear / degenerate

    final xc = (b1 * a22 - b2 * a12) / det;
    final yc = (a11 * b2 - a21 * b1) / det;

    // Radius
    final rSq = (sumX2 - 2.0 * xc * sumX + n * xc * xc + sumY2 - 2.0 * yc * sumY + n * yc * yc) / n;
    if (rSq <= 0.0) return null;
    final radius = math.sqrt(rSq);

    // Reject degenerate sizes
    if (radius < 2.0 || radius > 10000.0) return null;

    final center = Offset(xc, yc);

    // Measure radial errors for raw points
    double sumRadialErr = 0.0;
    double sumRadialErrSq = 0.0;
    double maxRadialErr = 0.0;

    for (final p in raw) {
      final r = (p - center).distance;
      final err = (r - radius).abs();
      sumRadialErr += err;
      sumRadialErrSq += err * err;
      if (err > maxRadialErr) maxRadialErr = err;
    }

    final avgRadialErr = sumRadialErr / n;
    final radiusVariation = math.sqrt(sumRadialErrSq / n);

    // Measure radial errors for processed points
    double procMaxRadialErr = 0.0;
    double procSumRadialErr = 0.0;

    for (final p in processed) {
      final r = (p - center).distance;
      final err = (r - radius).abs();
      procSumRadialErr += err;
      if (err > procMaxRadialErr) procMaxRadialErr = err;
    }
    final procAvgRadialErr =
        processed.isNotEmpty ? procSumRadialErr / processed.length : 0.0;

    return CircleAnalysisResult(
      fittedCenter: center,
      fittedRadius: radius,
      radiusVariation: radiusVariation,
      maxRadialErrorPx: maxRadialErr,
      averageRadialErrorPx: avgRadialErr,
      processedMaxRadialErrorPx: procMaxRadialErr,
      processedAvgRadialErrorPx: procAvgRadialErr,
    );
  }
}
