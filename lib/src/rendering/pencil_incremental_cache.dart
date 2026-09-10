import 'dart:ui';
import '../geometry/geometry_math.dart';
import '../geometry/stroke_cap.dart';
import '../geometry/stroke_join.dart';
import '../geometry/stroke_outline.dart';
import '../stroke/stroke.dart';
import '../stroke/stroke_point.dart';
import 'pencil_renderer.dart';

/// Frozen render representation of a finalized Pencil stroke.
class CachedPencilStroke {
  final Path visualPath;
  final double opacity;
  final Rect bounds;

  const CachedPencilStroke({
    required this.visualPath,
    required this.opacity,
    required this.bounds,
  });
}

/// Rolling performance telemetry metrics for the incremental Pencil pipeline.
class PencilIncrementalTelemetry {
  final double inputTimeMs;
  final double widthTimeMs;
  final double geometryTimeMs;
  final double contourTimeMs;
  final double drawSubmissionTimeMs;
  final double totalTimeMs;
  final double p50TotalMs;
  final double p95TotalMs;
  final double maxTotalMs;
  final int pointCount;
  final int contourVertexCount;

  const PencilIncrementalTelemetry({
    this.inputTimeMs = 0.0,
    this.widthTimeMs = 0.0,
    this.geometryTimeMs = 0.0,
    this.contourTimeMs = 0.0,
    this.drawSubmissionTimeMs = 0.0,
    this.totalTimeMs = 0.0,
    this.p50TotalMs = 0.0,
    this.p95TotalMs = 0.0,
    this.maxTotalMs = 0.0,
    this.pointCount = 0,
    this.contourVertexCount = 0,
  });
}

/// Renderer-specific incremental cache and session manager for Pencil strokes.
///
/// Ensures O(1) trailing-edge updates during active drawing and freezes
/// completed strokes to eliminate rebuilds on static repaints.
class PencilIncrementalCache {
  final PencilConfig config;

  // In-flight active stroke session
  String? _activeStrokeId;
  final List<StrokePoint> _filteredPoints = [];
  final List<double> _radii = [];

  // Permanent and active boundary vertices
  final List<Offset> _leftBoundary = [];
  final List<Offset> _rightBoundary = [];
  final List<Offset> _perturbedLeft = [];
  final List<Offset> _perturbedRight = [];
  double _leftArcLen = 0.0;
  double _rightArcLen = 0.0;

  // Active tip tracking & rollback
  int _nextInteriorJoinIndex = 1;
  bool _hasActiveTip = false;
  double _lastTipDistL = 0.0;
  double _lastTipDistR = 0.0;

  // Caps
  final List<Offset> _startCap = [];
  final List<Offset> _perturbedStartCap = [];
  final List<Offset> _currentEndCap = [];

  // Assembled active visual path
  Path _cachedVisualPath = Path();
  int _lastProcessedCount = 0;

  // Completed strokes cache
  final Map<String, CachedPencilStroke> _completedStrokes = {};

  // Rolling telemetry window (last 120 samples)
  final List<double> _recentTotalTimes = [];
  PencilIncrementalTelemetry _latestTelemetry =
      const PencilIncrementalTelemetry();

  PencilIncrementalCache({required this.config});

  PencilIncrementalTelemetry get latestTelemetry => _latestTelemetry;

  /// Retrieves a completed stroke's cached render representation, or null if uncached.
  CachedPencilStroke? getCompleted(String strokeId) =>
      _completedStrokes[strokeId];

  /// Stores a completed stroke's cached render representation.
  void cacheCompleted(String strokeId, CachedPencilStroke cached) {
    _completedStrokes[strokeId] = cached;
  }

  /// Clears all active and completed caches.
  void clear() {
    resetActive();
    _completedStrokes.clear();
  }

  /// Resets the active in-flight stroke cache.
  void resetActive() {
    _activeStrokeId = null;
    _filteredPoints.clear();
    _radii.clear();
    _leftBoundary.clear();
    _rightBoundary.clear();
    _perturbedLeft.clear();
    _perturbedRight.clear();
    _leftArcLen = 0.0;
    _rightArcLen = 0.0;
    _startCap.clear();
    _perturbedStartCap.clear();
    _currentEndCap.clear();
    _cachedVisualPath = Path();
    _lastProcessedCount = 0;
    _nextInteriorJoinIndex = 1;
    _hasActiveTip = false;
    _lastTipDistL = 0.0;
    _lastTipDistR = 0.0;
  }

  /// Incrementally updates the active stroke and returns the assembled visual [Path].
  Path updateActiveStroke(
    Stroke stroke, {
    double inputDurationMs = 0.0,
  }) {
    final swTotal = Stopwatch()..start();

    // Reset if this is a new stroke
    if (_activeStrokeId != stroke.id) {
      resetActive();
      _activeStrokeId = stroke.id;
    }

    final rawPoints = stroke.points;
    if (rawPoints.isEmpty) {
      _cachedVisualPath = Path();
      return _cachedVisualPath;
    }

    // 1. Filter new points
    for (int i = _lastProcessedCount; i < rawPoints.length; i++) {
      final p = rawPoints[i];
      if (_filteredPoints.isEmpty) {
        _filteredPoints.add(p);
      } else {
        if (GeometryMath.distance(_filteredPoints.last.position, p.position) >=
            1e-4) {
          _filteredPoints.add(p);
        }
      }
    }
    _lastProcessedCount = rawPoints.length;

    // Single point dab
    if (_filteredPoints.length == 1) {
      final r = config.widthProfile
          .computeRadii(
            _filteredPoints,
            baseWidth: stroke.baseWidth,
            isComplete: stroke.isComplete,
          )
          .first;
      _radii.clear();
      _radii.add(r);
      _cachedVisualPath = Path()
        ..addOval(
            Rect.fromCircle(center: _filteredPoints.first.position, radius: r));
      swTotal.stop();
      _recordTelemetry(
        inputMs: inputDurationMs,
        widthMs: 0.0,
        geomMs: 0.0,
        contourMs: 0.0,
        totalMs: swTotal.elapsedMicroseconds / 1000.0,
        ptCount: 1,
        vertexCount: 16,
      );
      return _cachedVisualPath;
    }

    // 2. Incremental Width Update
    final swWidth = Stopwatch()..start();
    _updateRadii(stroke.baseWidth, stroke.isComplete);
    swWidth.stop();

    // 3. Incremental Geometry Update
    final swGeom = Stopwatch()..start();
    _updateIncrementalGeometry(stroke.isComplete);
    swGeom.stop();

    // 4. Incremental Visual Contour / Path Assembly
    final swContour = Stopwatch()..start();
    _assembleVisualPath();
    swContour.stop();

    swTotal.stop();
    final totalMs = swTotal.elapsedMicroseconds / 1000.0;

    _recordTelemetry(
      inputMs: inputDurationMs,
      widthMs: swWidth.elapsedMicroseconds / 1000.0,
      geomMs: swGeom.elapsedMicroseconds / 1000.0,
      contourMs: swContour.elapsedMicroseconds / 1000.0,
      totalMs: totalMs,
      ptCount: _filteredPoints.length,
      vertexCount: _perturbedLeft.length +
          _perturbedRight.length +
          _startCap.length +
          _currentEndCap.length,
    );

    return _cachedVisualPath;
  }

  void _updateRadii(double baseWidth, bool isComplete) {
    if (_filteredPoints.length == _radii.length) return;

    _radii.clear();
    _radii.addAll(config.widthProfile.computeRadii(
      _filteredPoints,
      baseWidth: baseWidth,
      isComplete: isComplete,
    ));
  }

  void _updateIncrementalGeometry(bool isComplete) {
    const arcSteps = 8;
    final n = _filteredPoints.length;
    if (n < 2) return;

    // First two points: initialize start cap, L0, R0
    if (_leftBoundary.isEmpty) {
      final p0 = _filteredPoints[0].position;
      final p1 = _filteredPoints[1].position;
      final vStart = GeometryMath.normalize(p1 - p0);
      final nStart = GeometryMath.leftNormal(vStart);
      final r0 = _radii[0];

      final l0 = p0 + nStart * r0;
      final r0Pt = p0 - nStart * r0;

      final startCapPts = StrokeCapBuilder.buildStartCap(
        center: p0,
        tangent: vStart,
        l: l0,
        r: r0Pt,
        radius: r0,
        capType: StrokeCapType.round,
        steps: arcSteps,
      );

      _startCap.addAll(startCapPts);
      _perturbStartCap();

      _leftBoundary.add(l0);
      _rightBoundary.add(r0Pt);
      _appendPerturbedLeft(l0, initialNorm: nStart);
      _appendPerturbedRight(r0Pt, initialNorm: -nStart);
      _nextInteriorJoinIndex = 1;
      _hasActiveTip = false;
    }

    // If previous step had an active transient tip, roll it back so interior join can be placed
    if (_hasActiveTip && _leftBoundary.length >= 2) {
      _leftBoundary.removeLast();
      _perturbedLeft.removeLast();
      _leftArcLen -= _lastTipDistL;

      _rightBoundary.removeLast();
      _perturbedRight.removeLast();
      _rightArcLen -= _lastTipDistR;

      _hasActiveTip = false;
    }

    // Process all newly confirmed interior joins (points 1 to n-2)
    while (_nextInteriorJoinIndex <= n - 2) {
      final i = _nextInteriorJoinIndex;
      final pPrev = _filteredPoints[i - 1].position;
      final pCurr = _filteredPoints[i].position;
      final pNext = _filteredPoints[i + 1].position;
      final r = _radii[i];

      final vIn = GeometryMath.normalize(pCurr - pPrev);
      final vOut = GeometryMath.normalize(pNext - pCurr);

      final join = StrokeJoinBuilder.buildJoin(
        center: pCurr,
        vIn: vIn,
        vOut: vOut,
        radius: r,
        joinType: StrokeJoinType.round,
        arcSteps: arcSteps,
      );

      for (final pt in join.leftPoints) {
        _leftBoundary.add(pt);
        _appendPerturbedLeft(pt);
      }
      for (final pt in join.rightPoints) {
        _rightBoundary.add(pt);
        _appendPerturbedRight(pt);
      }

      _nextInteriorJoinIndex++;
    }

    // Compute updated tip cap at pLast (index n-1)
    final pLastPrev = _filteredPoints[n - 2].position;
    final pLast = _filteredPoints[n - 1].position;
    final vEnd = GeometryMath.normalize(pLast - pLastPrev);
    final nEnd = GeometryMath.leftNormal(vEnd);
    final rLast = _radii[n - 1];

    final lLast = pLast + nEnd * rLast;
    final rLastPt = pLast - nEnd * rLast;

    final endCapPts = StrokeCapBuilder.buildEndCap(
      center: pLast,
      tangent: vEnd,
      l: lLast,
      r: rLastPt,
      radius: rLast,
      capType: StrokeCapType.round,
      steps: arcSteps,
    );

    _currentEndCap.clear();
    _currentEndCap.addAll(endCapPts);

    // Append tip points to boundary
    _lastTipDistL = GeometryMath.distance(_leftBoundary.last, lLast);
    _lastTipDistR = GeometryMath.distance(_rightBoundary.last, rLastPt);

    _leftBoundary.add(lLast);
    _rightBoundary.add(rLastPt);
    _appendPerturbedLeft(lLast);
    _appendPerturbedRight(rLastPt);

    // Mark tip transient if stroke is still in-flight
    _hasActiveTip = !isComplete;
  }

  void _perturbStartCap() {
    _perturbedStartCap.clear();
    if (!config.enableLeadGrain || config.leadGrainAmplitude <= 0.0) {
      _perturbedStartCap.addAll(_startCap);
      return;
    }

    double capArc = 0.0;
    for (int i = 0; i < _startCap.length; i++) {
      final pt = _startCap[i];
      if (i > 0) capArc += GeometryMath.distance(_startCap[i - 1], pt);

      final prev = _startCap[(i - 1 + _startCap.length) % _startCap.length];
      final next = _startCap[(i + 1) % _startCap.length];
      final tangent = next - prev;
      final tangentLen = tangent.distance;
      if (tangentLen < 1e-5) {
        _perturbedStartCap.add(pt);
        continue;
      }
      final norm = Offset(-tangent.dy / tangentLen, tangent.dx / tangentLen);
      final s = (capArc + 150.0) / config.leadGrainWavelength;
      final noise = 0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
      _perturbedStartCap.add(pt + norm * (noise * config.leadGrainAmplitude));
    }
  }

  void _appendPerturbedLeft(Offset pt, {Offset? initialNorm}) {
    if (!config.enableLeadGrain || config.leadGrainAmplitude <= 0.0) {
      _perturbedLeft.add(pt);
      return;
    }

    if (_leftBoundary.length > 1) {
      _leftArcLen +=
          GeometryMath.distance(_leftBoundary[_leftBoundary.length - 2], pt);
    }

    Offset norm;
    if (_leftBoundary.length >= 2) {
      final prev = _leftBoundary[_leftBoundary.length - 2];
      final tangent = pt - prev;
      final dist = tangent.distance;
      norm = dist > 1e-5
          ? Offset(-tangent.dy / dist, tangent.dx / dist)
          : Offset.zero;
    } else {
      norm = initialNorm ?? Offset.zero;
    }

    final s = _leftArcLen / config.leadGrainWavelength;
    final noise = 0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
    _perturbedLeft.add(pt + norm * (noise * config.leadGrainAmplitude));
  }

  void _appendPerturbedRight(Offset pt, {Offset? initialNorm}) {
    if (!config.enableLeadGrain || config.leadGrainAmplitude <= 0.0) {
      _perturbedRight.add(pt);
      return;
    }

    if (_rightBoundary.length > 1) {
      _rightArcLen +=
          GeometryMath.distance(_rightBoundary[_rightBoundary.length - 2], pt);
    }

    Offset norm;
    if (_rightBoundary.length >= 2) {
      final prev = _rightBoundary[_rightBoundary.length - 2];
      final tangent = pt - prev;
      final dist = tangent.distance;
      norm = dist > 1e-5
          ? Offset(tangent.dy / dist, -tangent.dx / dist)
          : Offset.zero;
    } else {
      norm = initialNorm ?? Offset.zero;
    }

    final s = (_rightArcLen + 300.0) / config.leadGrainWavelength;
    final noise = 0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
    _perturbedRight.add(pt + norm * (noise * config.leadGrainAmplitude));
  }

  void _assembleVisualPath() {
    if (_perturbedLeft.isEmpty) return;

    final path = Path();
    path.moveTo(_perturbedLeft.first.dx, _perturbedLeft.first.dy);

    for (int i = 1; i < _perturbedLeft.length; i++) {
      path.lineTo(_perturbedLeft[i].dx, _perturbedLeft[i].dy);
    }

    // Perturb end cap
    if (config.enableLeadGrain &&
        config.leadGrainAmplitude > 0.0 &&
        _currentEndCap.isNotEmpty) {
      double endArc = 0.0;
      for (int i = 0; i < _currentEndCap.length; i++) {
        final pt = _currentEndCap[i];
        if (i > 0) endArc += GeometryMath.distance(_currentEndCap[i - 1], pt);
        final prev = _currentEndCap[
            (i - 1 + _currentEndCap.length) % _currentEndCap.length];
        final next = _currentEndCap[(i + 1) % _currentEndCap.length];
        final tangent = next - prev;
        final tLen = tangent.distance;
        if (tLen < 1e-5) {
          path.lineTo(pt.dx, pt.dy);
        } else {
          final norm = Offset(-tangent.dy / tLen, tangent.dx / tLen);
          final s = (_leftArcLen + endArc) / config.leadGrainWavelength;
          final noise =
              0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
          final displaced = pt + norm * (noise * config.leadGrainAmplitude);
          path.lineTo(displaced.dx, displaced.dy);
        }
      }
    } else {
      for (final pt in _currentEndCap) {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    // Right boundary reversed (from tip back to start)
    for (int i = _perturbedRight.length - 1; i >= 0; i--) {
      path.lineTo(_perturbedRight[i].dx, _perturbedRight[i].dy);
    }

    // Start cap
    final startPts =
        _perturbedStartCap.isNotEmpty ? _perturbedStartCap : _startCap;
    for (final pt in startPts) {
      path.lineTo(pt.dx, pt.dy);
    }

    path.close();
    _cachedVisualPath = path;
  }

  void _recordTelemetry({
    required double inputMs,
    required double widthMs,
    required double geomMs,
    required double contourMs,
    required double totalMs,
    required int ptCount,
    required int vertexCount,
  }) {
    _recentTotalTimes.add(totalMs);
    if (_recentTotalTimes.length > 120) {
      _recentTotalTimes.removeAt(0);
    }

    final sorted = List<double>.from(_recentTotalTimes)..sort();
    final p50 =
        sorted.isNotEmpty ? sorted[(sorted.length * 0.50).floor()] : totalMs;
    final p95 = sorted.isNotEmpty
        ? sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)]
        : totalMs;
    final maxT = sorted.isNotEmpty ? sorted.last : totalMs;

    _latestTelemetry = PencilIncrementalTelemetry(
      inputTimeMs: inputMs,
      widthTimeMs: widthMs,
      geometryTimeMs: geomMs,
      contourTimeMs: contourMs,
      drawSubmissionTimeMs: _latestTelemetry.drawSubmissionTimeMs,
      totalTimeMs: totalMs,
      p50TotalMs: p50,
      p95TotalMs: p95,
      maxTotalMs: maxT,
      pointCount: ptCount,
      contourVertexCount: vertexCount,
    );
  }

  /// Records draw submission duration for the current frame.
  void recordDrawSubmissionTime(double drawMs) {
    _latestTelemetry = PencilIncrementalTelemetry(
      inputTimeMs: _latestTelemetry.inputTimeMs,
      widthTimeMs: _latestTelemetry.widthTimeMs,
      geometryTimeMs: _latestTelemetry.geometryTimeMs,
      contourTimeMs: _latestTelemetry.contourTimeMs,
      drawSubmissionTimeMs: drawMs,
      totalTimeMs: _latestTelemetry.totalTimeMs + drawMs,
      p50TotalMs: _latestTelemetry.p50TotalMs,
      p95TotalMs: _latestTelemetry.p95TotalMs,
      maxTotalMs: _latestTelemetry.maxTotalMs,
      pointCount: _latestTelemetry.pointCount,
      contourVertexCount: _latestTelemetry.contourVertexCount,
    );
  }

  /// Builds a full one-shot batch visual contour path for [outline] using the
  /// exact same invariant parameterization as the incremental cache.
  Path buildBatchVisualContour(StrokeOutline outline) {
    if (outline.isEmpty) return Path();
    if (!config.enableLeadGrain || config.leadGrainAmplitude <= 0.0) {
      return outline.path;
    }

    final left = outline.leftBoundary;
    final right = outline.rightBoundary;
    if (left.isEmpty || right.isEmpty) return outline.path;

    final path = Path();
    double arcL = 0.0;

    // 1. Left boundary forward
    for (int i = 0; i < left.length; i++) {
      final pt = left[i];
      if (i > 0) arcL += GeometryMath.distance(left[i - 1], pt);

      Offset norm;
      if (i > 0) {
        final tangent = pt - left[i - 1];
        final dist = tangent.distance;
        norm = dist > 1e-5
            ? Offset(-tangent.dy / dist, tangent.dx / dist)
            : Offset.zero;
      } else if (left.length > 1) {
        final tangent = left[1] - pt;
        final dist = tangent.distance;
        norm = dist > 1e-5
            ? Offset(-tangent.dy / dist, tangent.dx / dist)
            : Offset.zero;
      } else {
        norm = Offset.zero;
      }

      final s = arcL / config.leadGrainWavelength;
      final noise = 0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
      final displaced = pt + norm * (noise * config.leadGrainAmplitude);
      if (i == 0) {
        path.moveTo(displaced.dx, displaced.dy);
      } else {
        path.lineTo(displaced.dx, displaced.dy);
      }
    }

    // 2. End cap forward
    if (outline.centerline.length >= 2) {
      final pLastPrev = outline.centerline[outline.centerline.length - 2];
      final pLast = outline.centerline.last;
      final vEnd = GeometryMath.normalize(pLast - pLastPrev);
      final rLast = GeometryMath.distance(pLast, left.last);
      final endCapPts = StrokeCapBuilder.buildEndCap(
        center: pLast,
        tangent: vEnd,
        l: left.last,
        r: right.last,
        radius: rLast,
        capType: StrokeCapType.round,
        steps: 8,
      );

      if (config.enableLeadGrain && config.leadGrainAmplitude > 0.0) {
        double endArc = 0.0;
        for (int i = 0; i < endCapPts.length; i++) {
          final pt = endCapPts[i];
          if (i > 0) endArc += GeometryMath.distance(endCapPts[i - 1], pt);
          final prev = endCapPts[(i - 1 + endCapPts.length) % endCapPts.length];
          final next = endCapPts[(i + 1) % endCapPts.length];
          final tangent = next - prev;
          final tLen = tangent.distance;
          if (tLen < 1e-5) {
            path.lineTo(pt.dx, pt.dy);
          } else {
            final norm = Offset(-tangent.dy / tLen, tangent.dx / tLen);
            final s = (arcL + endArc) / config.leadGrainWavelength;
            final noise =
                0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
            final displaced = pt + norm * (noise * config.leadGrainAmplitude);
            path.lineTo(displaced.dx, displaced.dy);
          }
        }
      } else {
        for (final pt in endCapPts) {
          path.lineTo(pt.dx, pt.dy);
        }
      }
    }

    // 3. Right boundary reversed
    double arcR = 0.0;
    final rightDistances = <double>[0.0];
    for (int i = 1; i < right.length; i++) {
      arcR += GeometryMath.distance(right[i - 1], right[i]);
      rightDistances.add(arcR);
    }

    for (int i = right.length - 1; i >= 0; i--) {
      final pt = right[i];
      Offset norm;
      if (i > 0) {
        final tangent = pt - right[i - 1];
        final dist = tangent.distance;
        norm = dist > 1e-5
            ? Offset(tangent.dy / dist, -tangent.dx / dist)
            : Offset.zero;
      } else if (right.length > 1) {
        final tangent = right[1] - pt;
        final dist = tangent.distance;
        norm = dist > 1e-5
            ? Offset(tangent.dy / dist, -tangent.dx / dist)
            : Offset.zero;
      } else {
        norm = Offset.zero;
      }

      final s = (rightDistances[i] + 300.0) / config.leadGrainWavelength;
      final noise = 0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
      final displaced = pt + norm * (noise * config.leadGrainAmplitude);
      path.lineTo(displaced.dx, displaced.dy);
    }

    // 4. Start cap
    if (outline.centerline.length >= 2) {
      final p0 = outline.centerline[0];
      final p1 = outline.centerline[1];
      final vStart = GeometryMath.normalize(p1 - p0);
      final r0 = GeometryMath.distance(p0, left.first);
      final startCapPts = StrokeCapBuilder.buildStartCap(
        center: p0,
        tangent: vStart,
        l: left.first,
        r: right.first,
        radius: r0,
        capType: StrokeCapType.round,
        steps: 8,
      );

      if (config.enableLeadGrain && config.leadGrainAmplitude > 0.0) {
        double startArc = 0.0;
        for (int i = 0; i < startCapPts.length; i++) {
          final pt = startCapPts[i];
          if (i > 0) startArc += GeometryMath.distance(startCapPts[i - 1], pt);
          final prev =
              startCapPts[(i - 1 + startCapPts.length) % startCapPts.length];
          final next = startCapPts[(i + 1) % startCapPts.length];
          final tangent = next - prev;
          final tLen = tangent.distance;
          if (tLen < 1e-5) {
            path.lineTo(pt.dx, pt.dy);
          } else {
            final norm = Offset(-tangent.dy / tLen, tangent.dx / tLen);
            final s = (startArc + 150.0) / config.leadGrainWavelength;
            final noise =
                0.65 * _hashNoise(s) + 0.35 * _hashNoise(s * 2.81 + 31.7);
            final displaced = pt + norm * (noise * config.leadGrainAmplitude);
            path.lineTo(displaced.dx, displaced.dy);
          }
        }
      } else {
        for (final pt in startCapPts) {
          path.lineTo(pt.dx, pt.dy);
        }
      }
    }

    path.close();
    return path;
  }

  /// Deterministic 1D hash value noise with cubic Hermite smoothstep interpolation.
  static double _hashNoise(double x) {
    final i0 = x.floor();
    final f = x - i0;
    final u = f * f * (3.0 - 2.0 * f);

    final n0 = _hash(i0);
    final n1 = _hash(i0 + 1);

    return n0 + u * (n1 - n0);
  }

  static double _hash(int n) {
    int h = n * 374761393 + 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    final unsigned = h & 0x7FFFFFFF;
    return (unsigned / 1073741823.5) - 1.0;
  }
}
