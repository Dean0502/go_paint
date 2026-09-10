import 'dart:ui';
import 'package:flutter/material.dart';
import '../geometry/crayon_width_profile.dart';
import '../geometry/stroke_cap.dart';
import '../geometry/stroke_geometry_builder.dart';
import '../geometry/stroke_join.dart';
import '../geometry/stroke_outline.dart';
import '../stroke/stroke.dart';
import 'crayon_incremental_cache.dart';
import 'stroke_renderer.dart';

/// Configuration options for the [CrayonRenderer].
class CrayonConfig {
  /// Profile governing velocity and pressure width modulation.
  final CrayonWidthProfile widthProfile;

  /// Nominal opacity for crayon marks (0.0 to 1.0).
  final double baseOpacity;

  /// Sensitivity of opacity to velocity changes (fast = lighter deposition, slow = heavier).
  final double velocityOpacityInfluence;

  /// Sensitivity of opacity to pressure changes (firm = deeper saturation, light = tooth skip).
  final double pressureOpacityInfluence;

  /// Whether subtle edge irregularity is applied to the visual contour.
  final bool enableEdgeVariation;

  /// Maximum amplitude in logical pixels for boundary displacement (typically 0.5–0.8 px).
  final double edgeVariationAmplitude;

  /// Spatial wavelength in logical pixels governing the scale of edge irregularity.
  final double edgeVariationWavelength;

  /// Whether subtle outer edge fringe pass is rendered for soft paper contact.
  final bool enableEdgeFringe;

  /// Stroke width for the edge fringe in logical pixels.
  final double edgeFringeWidth;

  /// Ratio of body opacity applied to the edge fringe pass.
  final double edgeFringeAlphaRatio;

  const CrayonConfig({
    this.widthProfile = const CrayonWidthProfile(),
    this.baseOpacity = 0.90,
    this.velocityOpacityInfluence = 0.10,
    this.pressureOpacityInfluence = 0.15,
    this.enableEdgeVariation = true,
    this.edgeVariationAmplitude = 0.65,
    this.edgeVariationWavelength = 18.0,
    this.enableEdgeFringe = true,
    this.edgeFringeWidth = 1.0,
    this.edgeFringeAlphaRatio = 0.25,
  })  : assert(baseOpacity >= 0.0 && baseOpacity <= 1.0, 'baseOpacity must be in [0, 1]'),
        assert(edgeVariationAmplitude >= 0.0, 'edgeVariationAmplitude must be non-negative'),
        assert(edgeVariationWavelength > 0.0, 'edgeVariationWavelength must be positive'),
        assert(edgeFringeWidth >= 0.0, 'edgeFringeWidth must be non-negative'),
        assert(edgeFringeAlphaRatio >= 0.0 && edgeFringeAlphaRatio <= 1.0,
            'edgeFringeAlphaRatio must be in [0, 1]');

  CrayonConfig copyWith({
    CrayonWidthProfile? widthProfile,
    double? baseOpacity,
    double? velocityOpacityInfluence,
    double? pressureOpacityInfluence,
    bool? enableEdgeVariation,
    double? edgeVariationAmplitude,
    double? edgeVariationWavelength,
    bool? enableEdgeFringe,
    double? edgeFringeWidth,
    double? edgeFringeAlphaRatio,
  }) {
    return CrayonConfig(
      widthProfile: widthProfile ?? this.widthProfile,
      baseOpacity: baseOpacity ?? this.baseOpacity,
      velocityOpacityInfluence: velocityOpacityInfluence ?? this.velocityOpacityInfluence,
      pressureOpacityInfluence: pressureOpacityInfluence ?? this.pressureOpacityInfluence,
      enableEdgeVariation: enableEdgeVariation ?? this.enableEdgeVariation,
      edgeVariationAmplitude: edgeVariationAmplitude ?? this.edgeVariationAmplitude,
      edgeVariationWavelength: edgeVariationWavelength ?? this.edgeVariationWavelength,
      enableEdgeFringe: enableEdgeFringe ?? this.enableEdgeFringe,
      edgeFringeWidth: edgeFringeWidth ?? this.edgeFringeWidth,
      edgeFringeAlphaRatio: edgeFringeAlphaRatio ?? this.edgeFringeAlphaRatio,
    );
  }
}

/// Professional Crayon brush renderer.
///
/// Features:
/// - Physical wax-and-pigment deposition model with rich coverage.
/// - Deterministic pseudo-random edge irregularity (simulating paper tooth contact).
/// - Pressure-dependent contact flattening and pigment saturation.
/// - Maintains the clean [StrokeOutline] foundation while deriving an organic visual contour.
/// - Pure vector dual-pass rendering without bitmap textures, particles, or circular stamps.
/// - O(1) incremental caching for 120 Hz live drawing with completed stroke path reuse.
class CrayonRenderer implements StrokeRenderer {
  final CrayonConfig config;
  final CrayonIncrementalCache _cache;

  CrayonRenderer([this.config = const CrayonConfig()])
      : _cache = CrayonIncrementalCache(config: config);

  /// Access to the underlying incremental cache and rolling telemetry.
  CrayonIncrementalCache get cache => _cache;
  CrayonIncrementalTelemetry get telemetry => _cache.latestTelemetry;

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
    final offsets = List<Offset>.generate(filtered.length, (i) => filtered[i].position);

    const builder = StrokeGeometryBuilder(
      cap: StrokeCapType.round,
      join: StrokeJoinType.round,
    );

    return builder.buildFromOffsetsAndRadii(
      offsets: offsets,
      radii: radii,
    );
  }

  /// Computes the stable pigment density / opacity for [stroke] bounded in [0.20, 1.0].
  double computeOpacity(Stroke stroke) {
    if (stroke.points.isEmpty) return config.baseOpacity;

    double sumV = 0.0;
    double sumP = 0.0;
    for (final pt in stroke.points) {
      sumV += pt.velocity;
      sumP += pt.pressure;
    }
    final avgV = sumV / stroke.points.length;
    final avgP = sumP / stroke.points.length;

    // Velocity dwell factor: slow movement deposits more wax; fast movement skips slightly
    final vMin = config.widthProfile.config.velocityMin;
    final vMax = config.widthProfile.config.velocityMax;
    final normV = (vMax > vMin) ? ((avgV - vMin) / (vMax - vMin)).clamp(0.0, 1.0) : 0.5;
    final vDelta = (0.5 - normV) * config.velocityOpacityInfluence;

    // Pressure factor: firm press drives wax deep into paper valleys
    final normP = avgP.clamp(0.0, 1.0);
    final pDelta = (normP - 0.5) * config.pressureOpacityInfluence;

    final effective = config.baseOpacity + vDelta + pDelta;
    return effective.clamp(0.35, 1.0);
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
  /// using deterministic, low-frequency, pseudo-random edge variation.
  Path deriveVisualContour(StrokeOutline outline) {
    return _cache.buildBatchVisualContour(outline);
  }

  @override
  void render(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final effectiveOpacity = computeOpacity(stroke);

    // 1. Single-point dab
    if (stroke.points.length == 1) {
      _renderDab(canvas, stroke, effectiveOpacity);
      return;
    }

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
          CachedCrayonStroke(
            visualPath: visualPath,
            opacity: effectiveOpacity,
            bounds: cleanOutline.bounds,
          ),
        );
      }
    } else {
      visualPath = _cache.updateActiveStroke(stroke);
    }

    if (visualPath.getBounds().isEmpty) return;

    final swDraw = Stopwatch()..start();

    // 4. Optional subtle edge coverage / tooth fringe pass
    if (config.enableEdgeFringe && config.edgeFringeWidth > 0.0) {
      final fringeAlpha = (effectiveOpacity * config.edgeFringeAlphaRatio).clamp(0.0, 1.0);
      final fringePaint = Paint()
        ..color = stroke.color.withValues(alpha: fringeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.edgeFringeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      canvas.drawPath(visualPath, fringePaint);
    }

    // 5. Dominant rich pigment wax core fill
    final bodyPaint = Paint()
      ..color = stroke.color.withValues(alpha: effectiveOpacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(visualPath, bodyPaint);

    swDraw.stop();
    if (!stroke.isComplete) {
      _cache.recordDrawSubmissionTime(swDraw.elapsedMicroseconds / 1000.0);
    }
  }

  void _renderDab(Canvas canvas, Stroke stroke, double opacity) {
    final point = stroke.points.first;
    final radius = config.widthProfile.computeRadii([point], baseWidth: stroke.baseWidth).first;
    if (radius <= 0.0) return;

    // Subtle edge fringe
    if (config.enableEdgeFringe && config.edgeFringeWidth > 0.0) {
      final fringeAlpha = (opacity * config.edgeFringeAlphaRatio).clamp(0.0, 1.0);
      final fringePaint = Paint()
        ..color = stroke.color.withValues(alpha: fringeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.edgeFringeWidth
        ..isAntiAlias = true;
      canvas.drawCircle(point.position, radius + config.edgeFringeWidth * 0.5, fringePaint);
    }

    // Dominant core dot
    final bodyPaint = Paint()
      ..color = stroke.color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(point.position, radius, bodyPaint);
  }
}
