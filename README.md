# go_paint (GO Engine) 🎨

[![pub package](https://img.shields.io/pub/v/go_paint.svg)](https://pub.dev/packages/go_paint)
[![Live Web Demo](https://img.shields.io/badge/demo-Live%20Web%20App-brightgreen.svg)](https://dean0502.github.io/go_paint/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Powered by the **GO Engine** — a high-performance, **120 Hz vector drawing, inking, and note-taking engine** for Flutter with dual-layer compositing, interactive vector stroke eraser, authentic crayon & pencil brushes, sub-millisecond incremental rendering, and advanced stylus palm rejection. Engineered for low-latency handwriting and scalable digital notebooks.

🎮 **[Try the Live Web Demo](https://dean0502.github.io/go_paint/)** — Test the 120 Hz vector inking, realistic graphite pencil, waxy crayon, and vector eraser right in your browser!

---

## ✨ Highlights

- ⚡ **Dual-Layer Compositor**: Background strokes are compiled into a GPU display list (`ui.Picture`). Renders **500+ historical strokes in 0.05 ms** ($O(1)$ constant time) while the active tip renders at **120 Hz** on an isolated foreground layer.
- 🧹 **Vector Stroke Eraser**: High-speed point-to-segment hit testing for instantaneous stroke deletion with unified `CanvasAction` Undo/Redo.
- ✍️ **Hardware Stylus & Palm Rejection**: Seamless palm rejection when writing with active pens (USI styluses on Amazon Fire Max 11, Apple Pencil, S-Pen).
- ✏️ **Authentic Graphite Pencil**: 3-tier graphite physics (crisp centerline lead contact spine + abraded paper tooth sheath + feathered dust bloom) with dynamic pressure modulation ($0.35 - 0.95$).
- 🖍️ **Organic Crayon Brush**: Multi-lobed waxy contour extrusion with high-frequency edge perturbation and dynamic exit-taper geometry.
- 📐 **Pure Vector Engine**: No bitmap textures, raster hacks, or particle spam. Everything is resolution-independent vector geometry that scales crisply to 4K displays.
- 🎯 **Kinematics & Prediction**: Built-in velocity/acceleration tracking, corner preservation, low-latency smoothing, and tip prediction.
- 🔄 **Undo / Redo & Serialization**: Action history stack supporting drawing and erasing, plus JSON-serializable stroke structures.

---

## 🚀 Getting Started

Add `go_paint` to your `pubspec.yaml`:

```yaml
# Stable release:
dependencies:
  go_paint: ^0.1.0

# Or test the 0.2.0-dev preview directly from GitHub:
dependencies:
  go_paint:
    git:
      url: https://github.com/Dean0502/go_paint.git
      ref: main
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

## 🗓️ Release Cadence & Advance Changelogs

`go_paint` follows a predictable, transparent monthly release cycle:
- **1-Month Advance Changelog Preview**: We release the changelog for the upcoming version one month in advance so developers and downstream teams always have a clear, forward-looking roadmap of what is coming.
- **Scheduled Monthly Release**: Formal releases to [pub.dev](https://pub.dev/packages/go_paint) occur on the **last day of every month**, provided there are significant improvements, performance optimizations, or new features.
- **Semantic Versioning**: Releases strictly adhere to SemVer (`MAJOR.MINOR.PATCH`).
- **Stability First**: All releases must maintain 100% test pass rates and zero analyzer warnings across supported platforms.

---

## 📄 License

MIT License — free for personal and commercial use. See [LICENSE](LICENSE) for details.

