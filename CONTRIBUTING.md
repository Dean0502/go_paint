# Contributing to go_paint 🎨

Thank you for your interest in contributing to **`go_paint`**! 

This project was created as a high-performance, 120 Hz vector drawing and painting engine for Flutter. It is designed to be lightweight, modular, and extensible. We warmly welcome contributions from the open-source community!

---

## 💡 Ways to Contribute

1. **New Brushes & Renderers**:
   - Have an idea for Watercolor, Chalk, Calligraphy, or Airbrush?
   - Implement the [`StrokeRenderer`](lib/src/rendering/stroke_renderer.dart) interface and submit a PR!
2. **Platform & Hardware Support**:
   - Apple Pencil (tilt, azimuth, hover preview)
   - Samsung S-Pen / Wacom stylus pressure curves
   - Web canvas optimization
3. **Performance & Math**:
   - Spline smoothing algorithms, geometry triangulation, shader optimizations
4. **Documentation & Examples**:
   - Tutorials, drawing samples, or example app enhancements

---

## 🛠️ Development Setup

1. **Clone and Install**:
   ```bash
   cd packages/go_paint
   flutter pub get
   ```

2. **Run Tests**:
   Ensure all existing tests pass before submitting code:
   ```bash
   flutter test
   ```

3. **Static Analysis**:
   Verify there are zero lint issues:
   ```bash
   flutter analyze
   ```

4. **Run the Example App**:
   ```bash
   cd example
   flutter run
   ```

---

## 📐 Architecture Guidelines

- **Zero Unnecessary Dependencies**: Keep the core drawing engine pure Flutter/Dart without heavy third-party packages.
- **Pure Vector First**: Prefer mathematical vector contours and hardware shaders over heavy bitmap textures or raster dumps.
- **120 Hz Frame Budget**: Any active drawing code must run under **8.33 ms** (ideally $< 3\text{ ms}$) without causing garbage collector (GC) pauses during gestures.

---

## 🗓️ Release Cadence & Advance Changelogs

We adhere to a regular, predictable release schedule:
- **1-Month Advance Changelog Preview**: We publish the changelog for the upcoming release one month prior so contributors, developers, and apps using `go_paint` have full visibility into upcoming features and improvements.
- **Monthly Cadence**: Releases to [pub.dev](https://pub.dev/packages/go_paint) occur on the **last day of each month**, provided significant improvements, brush additions, or performance optimizations have been merged and validated.
- **Pull Request Cutoff**: Non-critical features and PRs intended for the upcoming monthly release should be submitted and reviewed prior to the final week of the month to allow thorough regression testing.
- **Hotfixes**: Critical bug fixes (e.g. crashes or severe gesture stalls) are released immediately out-of-band as patch versions.

---

## 🤝 Community Maintenance

This is an open, community-driven project with zero corporate bureaucracy. If you are passionate about digital painting, vector geometry, or creative tools in Flutter and want to become a co-maintainer, please open an issue or reach out!

