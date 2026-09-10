import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Generates and manages a seamless, world-space sketch paper tooth texture
/// for realistic graphite pencil and crayon deposition.
///
/// Simulates physical cold-press paper fibers with microscopic peaks and valleys.
/// Peaks accumulate high graphite density, while valleys remain porous.
class PaperGrainTexture {
  static PaperGrainTexture? _instance;

  /// Singleton instance.
  static PaperGrainTexture get instance {
    _instance ??= PaperGrainTexture._();
    return _instance!;
  }

  /// Texture tile dimension in logical pixels.
  static const int tileSize = 128;

  late final ui.Image _textureImage;
  late final ImageShader _shader;

  PaperGrainTexture._() {
    _textureImage = _generatePaperTexture(tileSize);
    _shader = ImageShader(
      _textureImage,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );
  }

  /// The generated seamless paper texture image.
  ui.Image get image => _textureImage;

  /// World-space repeated shader for painting paths with natural paper tooth.
  ImageShader get shader => _shader;

  /// Generates a seamless, multi-octave sketch paper tooth tile.
  ///
  /// Uses periodic toroidal wrapping so borders align without visible seams.
  static ui.Image _generatePaperTexture(int size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(1337);

    // 1. Clear base with semi-transparent valley floor
    // This ensures light pencil strokes have visible porous valleys.
    final basePaint = Paint()..color = const Color(0x18FFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), basePaint);

    final dotPaint = Paint()..strokeCap = StrokeCap.round;

    // Helper to draw toroidal wrapped dots (guarantees seamless tiling)
    void drawWrappedDot(double x, double y, double radius, int alpha) {
      dotPaint
        ..color = Color.fromARGB(alpha, 255, 255, 255)
        ..strokeWidth = radius * 2.0;

      for (final dx in [-size.toDouble(), 0.0, size.toDouble()]) {
        for (final dy in [-size.toDouble(), 0.0, size.toDouble()]) {
          final px = x + dx;
          final py = y + dy;
          if (px >= -radius && px <= size + radius && py >= -radius && py <= size + radius) {
            canvas.drawPoints(ui.PointMode.points, [Offset(px, py)], dotPaint);
          }
        }
      }
    }

    // Helper to draw toroidal wrapped fiber micro-segments
    void drawWrappedFiber(double x1, double y1, double x2, double y2, double width, int alpha) {
      final fiberPaint = Paint()
        ..color = Color.fromARGB(alpha, 255, 255, 255)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;

      final sx = x2 - x1;
      final sy = y2 - y1;

      for (final dx in [-size.toDouble(), 0.0, size.toDouble()]) {
        for (final dy in [-size.toDouble(), 0.0, size.toDouble()]) {
          final px1 = x1 + dx;
          final py1 = y1 + dy;
          final px2 = px1 + sx;
          final py2 = py1 + sy;
          if ((px1 >= -5 && px1 <= size + 5) || (px2 >= -5 && px2 <= size + 5)) {
            canvas.drawLine(Offset(px1, py1), Offset(px2, py2), fiberPaint);
          }
        }
      }
    }

    // 2. Multi-scale paper fiber clusters (coarse paper pulp)
    const clusterCount = 280;
    for (int i = 0; i < clusterCount; i++) {
      final cx = random.nextDouble() * size;
      final cy = random.nextDouble() * size;
      final radius = 1.0 + random.nextDouble() * 2.0;
      final alpha = 40 + random.nextInt(80);
      drawWrappedDot(cx, cy, radius, alpha);
    }

    // 3. Microscopic cold-press pulp fibers (short randomized filament lines)
    const fiberCount = 500;
    for (int i = 0; i < fiberCount; i++) {
      final fx = random.nextDouble() * size;
      final fy = random.nextDouble() * size;
      final angle = random.nextDouble() * math.pi * 2;
      final len = 2.0 + random.nextDouble() * 4.5;
      final fx2 = fx + math.cos(angle) * len;
      final fy2 = fy + math.sin(angle) * len;
      final fAlpha = 50 + random.nextInt(110);
      drawWrappedFiber(fx, fy, fx2, fy2, 0.8 + random.nextDouble() * 0.8, fAlpha);
    }

    // 4. Sharp tooth peaks (high-frequency microscopic paper grains)
    // These are the physical points that catch pencil graphite lead.
    const peakCount = 1400;
    for (int i = 0; i < peakCount; i++) {
      final px = random.nextDouble() * size;
      final py = random.nextDouble() * size;
      final pRadius = 0.5 + random.nextDouble() * 0.9;
      // High alpha peaks: 160 - 255
      final pAlpha = 140 + random.nextInt(116);
      drawWrappedDot(px, py, pRadius, pAlpha);
    }

    // 5. Ultra-fine graphite lead catch points (sub-pixel highlights)
    const highlightCount = 600;
    for (int i = 0; i < highlightCount; i++) {
      final hx = random.nextDouble() * size;
      final hy = random.nextDouble() * size;
      drawWrappedDot(hx, hy, 0.5, 210 + random.nextInt(46));
    }

    final picture = recorder.endRecording();
    return picture.toImageSync(size, size);
  }
}
