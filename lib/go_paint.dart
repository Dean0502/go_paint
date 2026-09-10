/// A high-performance 120 Hz vector drawing and painting canvas for Flutter.
library go_paint;

// Input & Multi-touch
export 'src/input/pointer_sample.dart';
export 'src/input/pointer_input.dart';
export 'src/input/multi_touch_policy.dart';

// Modular Input Processor & Kinematics
export 'src/processor/stabilizer_config.dart';
export 'src/processor/noise_filter.dart';
export 'src/processor/kinematics.dart';
export 'src/processor/pressure_source.dart';
export 'src/processor/adaptive_smoother.dart';
export 'src/processor/corner_preserver.dart';
export 'src/processor/predictor.dart';
export 'src/processor/stroke_diagnostics.dart';
export 'src/processor/stroke_geometry_analyzer.dart';
export 'src/processor/benchmark_report.dart';
export 'src/processor/input_processor.dart';

// Stroke & Kinematics
export 'src/stroke/stroke.dart';
export 'src/stroke/stroke_point.dart';
export 'src/stroke/stabilizer.dart';
export 'src/stroke/catmull_rom.dart';

// Rendering & Brushes
export 'src/rendering/stroke_renderer.dart';
export 'src/rendering/outline_ink_renderer.dart';
export 'src/rendering/pencil_renderer.dart';
export 'src/rendering/pencil_incremental_cache.dart';
export 'src/rendering/crayon_renderer.dart';
export 'src/rendering/crayon_incremental_cache.dart';
export 'src/rendering/canvas_renderer.dart';
export 'src/rendering/paper_grain_texture.dart';
export 'src/geometry/pencil_width_profile.dart';
export 'src/geometry/crayon_width_profile.dart';

// Professional Stroke Geometry Engine (v0.4)
export 'src/geometry/stroke_geometry.dart';

// Controller & Widgets
export 'src/controller/kidz_canvas_controller.dart';
export 'src/widgets/kidz_canvas.dart';
