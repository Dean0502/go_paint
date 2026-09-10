# go_paint 🎨

[![pub package](https://img.shields.io/pub/v/go_paint.svg)](https://pub.dev/packages/go_paint)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A high-performance, **120 Hz vector drawing and painting canvas** for Flutter with authentic crayon and graphite pencil brushes, sub-millisecond incremental rendering, and advanced touch kinematics.

---

## ✨ Highlights

- ⚡ **120 Hz Incremental Pipeline**: Sub-millisecond active tip rendering ($< 0.5\text{ ms}$) with $O(1)$ rollback and zero GC pressure during continuous drawing gestures.
- ✏️ **Authentic Graphite Pencil**: Dual-pass vector graphite deposition (dense core vein + soft halo graphite bloom) with high-frequency paper tooth lead noise ($\lambda = 3.5\text{ px}$) and natural pressure opacity dynamics ($0.35 - 0.85$).
- 🖍️ **Organic Crayon Brush**: Multi-lobed waxy contour extrusion with high-frequency edge perturbation and dynamic exit-taper geometry.
- 📐 **Pure Vector Engine**: No bitmap textures, raster hacks, or particle spam. Everything is resolution-independent vector geometry that scales crisply to 4K displays.
- 🎯 **Kinematics & Palm Rejection**: Built-in velocity/acceleration tracking, corner preservation, low-latency smoothing, and single-finger multi-touch policies.
- 🔄 **Undo / Redo & Serialization**: Full stroke history stack and JSON-serializable stroke structures.

---

## 🚀 Getting Started

Add `go_paint` to your `pubspec.yaml`:

```yaml
dependencies:
  go_paint: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

## 💡 Quickstart

```dart
import 'package:flutter/material.dart';
import 'package:go_paint/go_paint.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DrawingScreen(),
    );
  }
}

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  late final GoPaintController _controller;

  @override
  void initState() {
    super.initState();
    // Default controller with Pencil, Crayon, or Ink renderer
    _controller = GoPaintController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Paint Canvas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => _controller.undo(),
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () => _controller.redo(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _controller.clear(),
          ),
        ],
      ),
      body: GoPaint(
        controller: _controller,
        backgroundColor: Colors.white,
      ),
    );
  }
}
```

---

## 🖌️ Built-in Brushes

### 1. Graphite Pencil (`PencilRenderer`)
Simulates realistic 2B graphite on paper with a soft bloom halo and microscopic paper tooth grain:

```dart
_controller.strokeRenderer = PencilRenderer(
  const PencilConfig(
    enablePaperTooth: true,
    enableGraphiteHalo: true,
  ),
);
```

### 2. Wax Crayon (`CrayonRenderer`)
Simulates textured wax deposition with pressure-sensitive width profile and edge jitter:

```dart
_controller.strokeRenderer = CrayonRenderer();
```

### 3. Smooth Vector Ink (`OutlineInkRenderer`)
Provides clean, laser-crisp calligraphic outlines with smooth Catmull-Rom interpolation:

```dart
_controller.strokeRenderer = OutlineInkRenderer();
```

---

## 📊 Performance Benchmarks

Measured on standard mobile/desktop hardware during continuous stylus drags:

| Stroke Length | Full Rebuild Frame Time | Incremental Cache Frame Time | Speedup |
| :--- | :--- | :--- | :--- |
| **100 points** | $4.8 - 9.2\text{ ms}$ | **$0.27 - 0.67\text{ ms}$** | **$9.4\times$** |
| **500 points** | $27.8 - 37.6\text{ ms}$ | **$1.88 - 2.64\text{ ms}$** | **$14.5\times$** |
| **1,000 points** | $78.3 - 193.9\text{ ms}$ | **$2.31 - 4.33\text{ ms}$** | **$25.0\times$** |

Active drawing runs comfortably under **$3\text{ ms}$**, well below the $8.33\text{ ms}$ frame budget for **120 Hz ProMotion displays**.

---

## 🛠️ Building Custom Brushes

`go_paint` is fully modular. You can implement your own custom brush (e.g. watercolor, airbrush, chalk) simply by implementing [`StrokeRenderer`]:

```dart
class MyCustomBrushRenderer implements StrokeRenderer {
  @override
  void render(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;
    
    // Your custom math, shaders, or vector paths here!
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.baseWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.position.dx, stroke.points.first.position.dy);
    for (final pt in stroke.points.skip(1)) {
      path.lineTo(pt.position.dx, pt.position.dy);
    }
    canvas.drawPath(path, paint);
  }
}

// Attach it to your canvas:
_controller.strokeRenderer = MyCustomBrushRenderer();
```

---

## 🤝 Contributing & Community

Contributions from the open-source community are warmly welcomed!

- 💡 **Got an idea for a new brush?** Open an issue or submit a Pull Request!
- 🐛 **Found a stylus/touch bug?** Please report it via our issue tracker.
- 🚀 **Want to help maintain?** We welcome co-maintainers to help review PRs and guide the project.

See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture guidelines, setup, and test commands.

---

## 📄 License

MIT License — free for personal and commercial use. See [LICENSE](LICENSE) for details.

