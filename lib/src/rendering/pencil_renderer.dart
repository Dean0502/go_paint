import 'package:flutter/material.dart';
import '../geometry/pencil_width_profile.dart';
import '../geometry/stroke_cap.dart';
import '../geometry/stroke_geometry_builder.dart';
import '../geometry/stroke_join.dart';
import '../geometry/stroke_outline.dart';
import '../stroke/stroke.dart';
import 'paper_grain_texture.dart';
import 'pencil_incremental_cache.dart';
import 'stroke_renderer.dart';

/// Configuration options for the [PencilRenderer].
class PencilConfig {
  /// Profile governing velocity and pressure width modulation and endpoint taper.
  final PencilWidthProfile widthProfile;

  /// Nominal opacity for pencil marks (0.0 to 1.0). Realistic graphite defaults to ~0.65.
  final double baseOpacity;

  /// Sensitivity of opacity to velocity changes (fast = lighter, slow = darker).
  final double velocityOpacityInfluence;

  /// Sensitivity of opacity to pressure changes (firm = darker, light = lighter).
  final double pressureOpacityInfluence;

  /// Whether fine procedural lead grain / paper tooth is applied along the pencil contour.
  final bool enableLeadGrain;

  /// Micro-displacement amplitude of the lead grain in logical pixels (default: 0.65 px).
  final double leadGrainAmplitude;

  /// Spatial wavelength of the high-frequency lead grain in logical pixels (default: 3.2 px).
  final double leadGrainWavelength;

  /// Whether world-space sketch paper tooth texture shader is applied to the pencil mark.
  final bool enablePaperTooth;

  /// Underlying graphite wash ratio (0.0 to 1.0) under the paper tooth peaks (default: 0.22).
  final double underwashAlphaRatio;

  /// Whether a soft graphite halo / dust bloom is rendered around the pencil core.
  final bool enableGraphiteHalo;

  /// Stroke width for the soft graphite halo in logical pixels.
  final double graphiteHaloWidth;

  /// Scalar ratio (0.0 to 1.0) of body opacity applied to the graphite halo pass.
  final double graphiteHaloAlphaRatio;

  // Backward-compatibility getters
  bool get enableEdgeSoftness => enableGraphiteHalo;
  double get edgeSoftnessWidth => graphiteHaloWidth;
  double get edgeSoftnessAlphaRatio => graphiteHaloAlphaRatio;

  const PencilConfig({
    this.widthProfile = const PencilWidthProfile(),
    this.baseOpacity = 0.70,
    this.velocityOpacityInfluence = 0.15,
    this.pressureOpacityInfluence = 0.20,
    this.enableLeadGrain = true,
    this.leadGrainAmplitude = 0.65,
    this.leadGrainWavelength = 3.2,
    this.enablePaperTooth = true,
    this.underwashAlphaRatio = 0.22,
    this.enableGraphiteHalo = true,
    this.graphiteHaloWidth = 1.2,
    this.graphiteHaloAlphaRatio = 0.35,
    bool? enableEdgeSoftness,
    double? edgeSoftnessWidth,
    double? edgeSoftnessAlphaRatio,
  })  : assert(baseOpacity >= 0.0 && baseOpacity <= 1.0,
            'baseOpacity must be in [0, 1]'),
        assert(leadGrainAmplitude >= 0.0,
            'leadGrainAmplitude must be non-negative'),
        assert(
            leadGrainWavelength > 0.0, 'leadGrainWavelength must be positive'),
        assert(underwashAlphaRatio >= 0.0 && underwashAlphaRatio <= 1.0,
            'underwashAlphaRatio must be in [0, 1]'),
        assert(
            graphiteHaloWidth >= 0.0, 'graphiteHaloWidth must be non-negative'),
        assert(graphiteHaloAlphaRatio >= 0.0 && graphiteHaloAlphaRatio <= 1.0,
            'graphiteHaloAlphaRatio must be in [0, 1]');

  PencilConfig copyWith({
    PencilWidthProfile? widthProfile,
    double? baseOpacity,
    double? velocityOpacityInfluence,
    double? pressureOpacityInfluence,
    bool? enableLeadGrain,
    double? leadGrainAmplitude,
    double? leadGrainWavelength,
    bool? enablePaperTooth,
    double? underwashAlphaRatio,
    bool? enableGraphiteHalo,
    double? graphiteHaloWidth,
    double? graphiteHaloAlphaRatio,
    bool? enableEdgeSoftness,
    double? edgeSoftnessWidth,
    double? edgeSoftnessAlphaRatio,
  }) {
    return PencilConfig(
      widthProfile: widthProfile ?? this.widthProfile,
      baseOpacity: baseOpacity ?? this.baseOpacity,
      velocityOpacityInfluence:
          velocityOpacityInfluence ?? this.velocityOpacityInfluence,
      pressureOpacityInfluence:
          pressureOpacityInfluence ?? this.pressureOpacityInfluence,
      enableLeadGrain: enableLeadGrain ?? this.enableLeadGrain,
      leadGrainAmplitude: leadGrainAmplitude ?? this.leadGrainAmplitude,
      leadGrainWavelength: leadGrainWavelength ?? this.leadGrainWavelength,
      enablePaperTooth: enablePaperTooth ?? this.enablePaperTooth,
      underwashAlphaRatio: underwashAlphaRatio ?? this.underwashAlphaRatio,
      enableGraphiteHalo:
          enableGraphiteHalo ?? enableEdgeSoftness ?? this.enableGraphiteHalo,
      graphiteHaloWidth:
          graphiteHaloWidth ?? edgeSoftnessWidth ?? this.graphiteHaloWidth,
      graphiteHaloAlphaRatio: graphiteHaloAlphaRatio ??
          edgeSoftnessAlphaRatio ??
          this.graphiteHaloAlphaRatio,
    );
  }
}

/// Authentic Graphite Pencil brush renderer.
///
/// Features:
/// - Velocity-based width and deposition variation (faint glide on fast strokes).
/// - Hardware and simulated pressure sensitivity (silvery 4H touch to deep 2B graphite).
/// - High-frequency lead tooth grain simulating physical graphite on sketch paper.
/// - Dual-pass graphite deposition: dense core lead track with soft lead dust bloom.
/// - Incremental cache for real-time 120 Hz live drawing and frozen completed stroke reuse.
/// - Built on the v0.4 clean mathematical [StrokeGeometryBuilder].
class PencilRenderer implements StrokeRenderer {
  final PencilConfig config;
  final PencilIncrementalCache _cache;

  PencilRenderer([this.config = const PencilConfig()])
      : _cache = PencilIncrementalCache(config: config);

  /// Access to the underlying incremental cache and rolling telemetry.
  PencilIncrementalCache get cache => _cache;
  PencilIncrementalTelemetry get telemetry => _cache.latestTelemetry;

  /// Clears the renderer cache.
  void clearCache() => _cache.clear();

  /// Computes the clean, unperturbed mathematical [StrokeOutline] for [stroke].
  StrokeOutline computeOutline(Stroke stroke) {
    final filtered = StrokeGeometryBuilder.filterPoints(stroke.points);
    if (filtered.isEmpty) return StrokeOutline.empty();

    final radii = config.widthProfile.computeRadii(
      filtered,
      baseWidth: stroke.baseWidth,
      isComplete: stroke.isComplete,
    );
    final offsets =
        List<Offset>.generate(filtered.length, (i) => filtered[i].position);

    const builder = StrokeGeometryBuilder(
      cap: StrokeCapType.round,
      join: StrokeJoinType.round,
    );

    return builder.buildFromOffsetsAndRadii(
      offsets: offsets,
      radii: radii,
    );
  }

  /// Computes the stable effective graphite opacity for [stroke].
  double computeOpacity(Stroke stroke) {
    if (stroke.points.isEmpty) return config.baseOpacity;

    // Calculate stroke average velocity and pressure
    double sumV = 0.0;
    double sumP = 0.0;
    for (final pt in stroke.points) {
      sumV += pt.velocity;
      sumP += pt.pressure;
    }
    final avgV = sumV / stroke.points.length;
    final avgP = sumP / stroke.points.length;

    // Velocity factor: higher speed -> slightly lighter lead deposition
    final vMin = config.widthProfile.config.velocityMin;
    final vMax = config.widthProfile.config.velocityMax;
    final normV =
        (vMax > vMin) ? ((avgV - vMin) / (vMax - vMin)).clamp(0.0, 1.0) : 0.5;
    final vDelta = (0.5 - normV) * config.velocityOpacityInfluence;

    // Pressure factor: firm press drives rich graphite into paper; light press skips peaks
    final normP = avgP.clamp(0.0, 1.0);
    final pDelta = (normP - 0.5) * config.pressureOpacityInfluence;

    final effective = config.baseOpacity + vDelta + pDelta;
    return effective.clamp(0.25, 0.95);
  }

  /// Computes per-point radii list for [stroke].
  List<double> computePointRadii(Stroke stroke) {
    final filtered = StrokeGeometryBuilder.filterPoints(stroke.points);
    return config.widthProfile.computeRadii(
      filtered,
      baseWidth: stroke.baseWidth,
      isComplete: stroke.isComplete,
    );
  }

  /// Derives an organic visual contour path from the clean [StrokeOutline]
  /// using high-frequency lead grain noise.
  Path deriveVisualContour(StrokeOutline outline) {
    return _cache.buildBatchVisualContour(outline);
  }

  @override
  void render(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty || stroke.baseWidth <= 0.0) return;

    final effectiveOpacity = computeOpacity(stroke);

    // 1. Single point tap / dab
    if (stroke.points.length == 1) {
      _renderDab(canvas, stroke, effectiveOpacity);
      return;
    }

    final swDraw = Stopwatch()..start();
    Path visualPath;

    if (stroke.isComplete) {
      final cached = _cache.getCompleted(stroke.id);
      if (cached != null) {
        visualPath = cached.visualPath;
      } else {
        final cleanOutline = computeOutline(stroke);
        if (cleanOutline.isEmpty) return;
        visualPath = deriveVisualContour(cleanOutline);
        _cache.cacheCompleted(
          stroke.id,
          CachedPencilStroke(
            visualPath: visualPath,
            opacity: effectiveOpacity,
            bounds: cleanOutline.bounds,
          ),
        );
      }
    } else {
      visualPath = _cache.updateActiveStroke(stroke);
    }

    // 1. Pass 1: Abraded Graphite Sheath (Paper Tooth Texture)
    // Fills visualPath with paper grain texture without hard perimeter borders or flat underwash
    final pts = stroke.points;
    double sumP = 0.0;
    for (final p in pts) {
      sumP += p.pressure;
    }
    final avgP = (sumP / pts.length).clamp(0.0, 1.0);

    final sheathAlpha =
        (effectiveOpacity * (0.60 + 0.40 * avgP)).clamp(0.0, 1.0);
    final sheathPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (config.enablePaperTooth) {
      sheathPaint
        ..shader = PaperGrainTexture.instance.shader
        ..colorFilter = ColorFilter.mode(
          stroke.color.withValues(alpha: sheathAlpha),
          BlendMode.srcIn,
        );
    } else {
      sheathPaint.color = stroke.color.withValues(alpha: sheathAlpha);
    }
    canvas.drawPath(visualPath, sheathPaint);

    // Build smooth centerline path for core spine & halo
    final centerPath = Path();
    centerPath.moveTo(pts.first.position.dx, pts.first.position.dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1].position;
      final p1 = pts[i].position;
      final mid = Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      centerPath.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    centerPath.lineTo(pts.last.position.dx, pts.last.position.dy);

    // 2. Pass 2: Soft Graphite Halo / Dust Bloom along the centerline
    if (config.enableGraphiteHalo && config.graphiteHaloWidth > 0.0) {
      final haloAlpha = (effectiveOpacity *
              config.graphiteHaloAlphaRatio *
              (0.45 + 0.55 * avgP))
          .clamp(0.0, 1.0);
      final haloPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (stroke.baseWidth * 1.25).clamp(0.0, 12.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (config.enablePaperTooth) {
        haloPaint
          ..shader = PaperGrainTexture.instance.shader
          ..colorFilter = ColorFilter.mode(
            stroke.color.withValues(alpha: haloAlpha),
            BlendMode.srcIn,
          );
      } else {
        haloPaint.color = stroke.color.withValues(alpha: haloAlpha);
      }
      canvas.drawPath(centerPath, haloPaint);
    }

    // 3. Pass 3: Dense Core Graphite Spine (Center contact point of the lead)
    final coreWidth =
        (stroke.baseWidth * (0.45 + 0.35 * avgP)).clamp(0.0, stroke.baseWidth);
    final coreAlpha =
        (effectiveOpacity * (0.35 + 0.55 * avgP)).clamp(0.0, 0.95);
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = coreWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = stroke.color.withValues(alpha: coreAlpha);
    canvas.drawPath(centerPath, corePaint);

    swDraw.stop();
    _cache.recordDrawSubmissionTime(swDraw.elapsedMicroseconds / 1000.0);
  }

  void _renderDab(Canvas canvas, Stroke stroke, double opacity) {
    final point = stroke.points.first;
    final radius = config.widthProfile.computeRadii(
      [point],
      baseWidth: stroke.baseWidth,
      isComplete: stroke.isComplete,
    ).first;
    if (radius <= 0.0) return;

    // Soft halo bloom for dot
    if (config.enableGraphiteHalo && config.graphiteHaloWidth > 0.0) {
      final haloAlpha =
          (opacity * config.graphiteHaloAlphaRatio).clamp(0.0, 1.0);
      final haloPaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      if (config.enablePaperTooth) {
        haloPaint
          ..shader = PaperGrainTexture.instance.shader
          ..colorFilter = ColorFilter.mode(
            stroke.color.withValues(alpha: haloAlpha),
            BlendMode.srcIn,
          );
      } else {
        haloPaint.color = stroke.color.withValues(alpha: haloAlpha);
      }
      canvas.drawCircle(point.position, radius * 1.3, haloPaint);
    }

    // Core lead dot with crisp center point
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = stroke.color.withValues(alpha: opacity);
    canvas.drawCircle(point.position, radius * 0.7, corePaint);
  }
}
