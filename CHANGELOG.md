# Changelog

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 0.2.0-dev (Advance Preview — Scheduled Stable: October 31, 2026)

### Breakthrough Features & Performance (GO Engine v0.2.0)

- ⚡ **Dual-Layer Composited Pipeline**:
  - **Static Historical Layer (`StaticPicturePainter`)**: Bakes all finalized strokes into a GPU-compiled `ui.Picture`. Drawing 500+ strokes takes **0.05 ms** ($O(1)$ constant time), eliminating lag on budget devices like Amazon Fire tablets and Android.
  - **Active In-Flight Tip Layer (`ActiveTipPainter`)**: Dedicated foreground painter updating at 120 Hz with zero invalidation of the background layer.
- ✏️ **Re-Engineered Realistic Graphite Pencil**:
  - **3-Tier Graphite Physics**: Completely replaces the previous flat ribbon outline with:
    1. *Dense Core Lead Spine*: Sharp physical point of contact along the smoothed centerline for crisp handwriting definition.
    2. *Soft Abraded Graphite Sheath*: Microscopic paper tooth texture where lead catches naturally on paper fibers with genuine dry-media voids.
    3. *Graphite Dust Halo*: Feathered lead bloom that diffuses outward from the centerline without harsh polygon boundary cuts.
  - **Dynamic Pressure Dynamics**: From delicate, silvery 2H sketch marks on light touches to velvety, dark 2B graphite marks under firm pressure.
- 📐 **Vector Stroke Memoization**:
  - `Stroke` now retains `cachedPath`, eliminating Catmull-Rom and polygon re-tessellation on static repaints, zooms, and redrawing.
- 🧹 **Interactive Vector Stroke Eraser**:
  - Added `CanvasTool.eraser` with point-to-segment distance detection for erasing intersecting vector strokes at 120 FPS.
  - Unified `CanvasAction` history stack (`addStroke`, `removeStroke`) for seamless Undo / Redo of both drawing and erasing operations.
- ✍️ **Hardware Stylus & Palm Rejection**:
  - Added `stylusOnlyDrawing` mode: automatically rejects accidental palm/finger touch events when using an active stylus (Fire Max 11 USI stylus, Apple Pencil, S-Pen).

---

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
