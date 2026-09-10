# Changelog

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 0.1.0

### Features

- **120 Hz Incremental Pipeline**: Sub-millisecond active tip rendering ($< 0.5\text{ ms}$) with $O(1)$ rollback and zero GC pressure during continuous drawing gestures.
- **Authentic Graphite Pencil Engine**: Dual-pass vector graphite deposition (dense core vein + soft halo graphite bloom) with high-frequency paper tooth lead noise ($\lambda = 3.5\text{ px}$) and natural pressure opacity modulation ($0.35 - 0.85$).
- **Organic Crayon Brush Engine**: Multi-lobed waxy contour extrusion with high-frequency edge perturbation and dynamic exit-taper geometry.
- **Advanced Kinematics & Input Processing**:
  - Velocity, acceleration, and jerk tracking.
  - Directional angular velocity detection with automatic sharp corner preservation.
  - Adaptive low-latency double-exponential Kalman-style smoother.
  - Multi-touch palm rejection and single-finger drawing policy.
- **Stroke Geometry Engine**:
  - Catmull-Rom spline interpolation.
  - Adaptive perpendicular vector extrusion.
  - Round cap and bevel/miter join generation.
  - Pure vector representation with deterministic geometry.
- **State Management & Serialization**:
  - `GoPaintController` (and `KidzCanvasController`) with full undo/redo history.
  - Serializable stroke point models for cloud sync and offline persistence.
- **Interactive Widgets**:
  - `GoPaint` (and `KidzCanvas`) widget with repaint boundary isolation.
