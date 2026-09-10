import 'package:flutter/material.dart';
import '../input/pointer_input.dart';
import '../input/pointer_sample.dart';
import '../rendering/stroke_renderer.dart';
import '../stroke/stroke.dart';
import '../processor/benchmark_report.dart';
import '../processor/stroke_diagnostics.dart';
import '../processor/stabilizer_config.dart';

/// Central state coordinator for `kidz_canvas`.
///
/// Implements [ChangeNotifier] so [CustomPainter] repaints at high frequency
/// without triggering full widget rebuilds.
class KidzCanvasController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  final List<StrokeBenchmarkReport> _benchmarkHistory = [];
  final PointerInput _pointerInput;

  Color _activeColor;
  double _activeWidth;
  StrokeRenderer _strokeRenderer;

  KidzCanvasController({
    Color initialColor = Colors.black,
    double initialWidth = 4.0,
    StrokeRenderer strokeRenderer = const BasicInkRenderer(),
    PointerInput? pointerInput,
  })  : _activeColor = initialColor,
        _activeWidth = initialWidth,
        _strokeRenderer = strokeRenderer,
        _pointerInput = pointerInput ?? PointerInput();

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _pointerInput.activeStroke;
  bool get isDrawing => _pointerInput.isDrawing;
  PointerInput get pointerInput => _pointerInput;
  StrokeDiagnostics get diagnostics => _pointerInput.diagnostics;
  StabilizerConfig get config => _pointerInput.stabilizer.config;

  /// The quantitative benchmark report from the most recently completed stroke.
  StrokeBenchmarkReport? get lastBenchmarkReport => _pointerInput.lastBenchmarkReport;

  /// Full chronological session history of benchmark reports.
  List<StrokeBenchmarkReport> get benchmarkHistory => List.unmodifiable(_benchmarkHistory);

  /// Clears recorded benchmark history for this session.
  void clearBenchmarkHistory() {
    _benchmarkHistory.clear();
    notifyListeners();
  }

  /// Sets device, refresh rate, and benchmark mode for upcoming test strokes.
  void setBenchmarkContext({
    String? testMode,
    String? platform,
    String? androidVersion,
    String? device,
    String? cpuArchitecture,
    double? refreshRate,
    double? devicePixelRatio,
    String? screenResolution,
  }) {
    _pointerInput.setBenchmarkContext(
      testMode: testMode,
      platform: platform,
      androidVersion: androidVersion,
      device: device,
      cpuArchitecture: cpuArchitecture,
      refreshRate: refreshRate,
      devicePixelRatio: devicePixelRatio,
      screenResolution: screenResolution,
    );
  }

  void updateConfig(StabilizerConfig newConfig) {
    _pointerInput.updateConfig(newConfig);
    notifyListeners();
  }

  Color get activeColor => _activeColor;
  set activeColor(Color c) {
    _activeColor = c;
    notifyListeners();
  }

  double get activeWidth => _activeWidth;
  set activeWidth(double w) {
    _activeWidth = w;
    notifyListeners();
  }

  StrokeRenderer get strokeRenderer => _strokeRenderer;
  set strokeRenderer(StrokeRenderer r) {
    _strokeRenderer = r;
    notifyListeners();
  }

  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Pointer down event ingestion
  void handlePointerDown(PointerSample sample) {
    final stroke = _pointerInput.onPointerDown(
      sample,
      color: _activeColor,
      width: _activeWidth,
    );
    if (stroke != null) {
      if (stroke.isComplete) {
        _strokes.add(stroke);
        _redoStack.clear();
        final rep = _pointerInput.lastBenchmarkReport;
        if (rep != null) {
          _benchmarkHistory.add(rep);
        }
      }
      notifyListeners();
    }
  }

  /// Pointer move event ingestion
  void handlePointerMove(PointerSample sample) {
    final stroke = _pointerInput.onPointerMove(sample);
    if (stroke != null) {
      notifyListeners();
    }
  }

  /// Pointer up event ingestion
  void handlePointerUp(PointerSample sample) {
    final completedStroke = _pointerInput.onPointerUp(sample);
    if (completedStroke != null) {
      _strokes.add(completedStroke);
      _redoStack.clear(); // Clear redo on new action
      final rep = _pointerInput.lastBenchmarkReport;
      if (rep != null) {
        _benchmarkHistory.add(rep);
      }
      notifyListeners();
    }
  }

  /// Pointer cancel event ingestion
  void handlePointerCancel(PointerSample sample) {
    _pointerInput.onPointerCancel(sample);
    notifyListeners();
  }

  /// Reverts the most recent stroke.
  void undo() {
    if (_strokes.isEmpty) return;
    final last = _strokes.removeLast();
    _redoStack.add(last);
    notifyListeners();
  }

  /// Reapplies the most recently reverted stroke.
  void redo() {
    if (_redoStack.isEmpty) return;
    final stroke = _redoStack.removeLast();
    _strokes.add(stroke);
    notifyListeners();
  }

  /// Clears all strokes on the canvas.
  void clear() {
    if (_strokes.isEmpty && _redoStack.isEmpty && !isDrawing) return;
    _strokes.clear();
    _redoStack.clear();
    _pointerInput.reset();
    notifyListeners();
  }
}

/// Package-level alias for [KidzCanvasController].
typedef GoPaintController = KidzCanvasController;

