import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../input/pointer_input.dart';
import '../input/pointer_sample.dart';
import '../rendering/stroke_renderer.dart';
import '../stroke/stroke.dart';
import '../processor/benchmark_report.dart';
import '../processor/stroke_diagnostics.dart';
import '../processor/stabilizer_config.dart';

/// Interactive tool modes for the drawing canvas.
enum CanvasTool {
  /// Standard drawing / inking tool.
  pen,

  /// Fast vector stroke eraser that removes any intersected stroke.
  eraser,
}

/// Action type for the undo/redo history stack.
enum CanvasActionType { addStroke, removeStroke }

/// Represents an undoable drawing or editing operation.
class CanvasAction {
  final CanvasActionType type;
  final Stroke stroke;
  final int index;
  const CanvasAction(this.type, this.stroke, [this.index = -1]);
}

class _InternalNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Central state coordinator for `kidz_canvas`.
///
/// Implements [ChangeNotifier] so [CustomPainter] repaints at high frequency
/// without triggering full widget rebuilds.
class KidzCanvasController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  final List<CanvasAction> _undoActions = [];
  final List<CanvasAction> _redoActions = [];
  final List<StrokeBenchmarkReport> _benchmarkHistory = [];
  final PointerInput _pointerInput;

  final _InternalNotifier _staticRepaintNotifier = _InternalNotifier();
  final _InternalNotifier _activeRepaintNotifier = _InternalNotifier();

  Color _activeColor;
  double _activeWidth;
  StrokeRenderer _strokeRenderer;
  CanvasTool _activeTool = CanvasTool.pen;
  double _eraserRadius = 16.0;
  bool _stylusOnlyDrawing = false;

  KidzCanvasController({
    Color initialColor = Colors.black,
    double initialWidth = 4.0,
    StrokeRenderer strokeRenderer = const BasicInkRenderer(),
    PointerInput? pointerInput,
    CanvasTool initialTool = CanvasTool.pen,
    double eraserRadius = 16.0,
    bool stylusOnlyDrawing = false,
  })  : _activeColor = initialColor,
        _activeWidth = initialWidth,
        _strokeRenderer = strokeRenderer,
        _pointerInput = pointerInput ?? PointerInput(),
        _activeTool = initialTool,
        _eraserRadius = eraserRadius,
        _stylusOnlyDrawing = stylusOnlyDrawing;

  /// Dedicated listenable for the static historical layer (ui.Picture cached).
  Listenable get staticRepaintListenable => _staticRepaintNotifier;

  /// Dedicated listenable for the active tip layer (120 Hz in-flight stroke).
  Listenable get activeRepaintListenable => _activeRepaintNotifier;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _pointerInput.activeStroke;
  bool get isDrawing => _pointerInput.isDrawing;
  PointerInput get pointerInput => _pointerInput;
  StrokeDiagnostics get diagnostics => _pointerInput.diagnostics;
  StabilizerConfig get config => _pointerInput.stabilizer.config;

  CanvasTool get activeTool => _activeTool;
  set activeTool(CanvasTool tool) {
    if (_activeTool == tool) return;
    _activeTool = tool;
    notifyListeners();
  }

  double get eraserRadius => _eraserRadius;
  set eraserRadius(double r) {
    _eraserRadius = r;
    notifyListeners();
  }

  bool get stylusOnlyDrawing => _stylusOnlyDrawing;
  set stylusOnlyDrawing(bool val) {
    _stylusOnlyDrawing = val;
    notifyListeners();
  }

  /// The quantitative benchmark report from the most recently completed stroke.
  StrokeBenchmarkReport? get lastBenchmarkReport =>
      _pointerInput.lastBenchmarkReport;

  /// Full chronological session history of benchmark reports.
  List<StrokeBenchmarkReport> get benchmarkHistory =>
      List.unmodifiable(_benchmarkHistory);

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
    _staticRepaintNotifier.notify();
    _activeRepaintNotifier.notify();
    notifyListeners();
  }

  bool get canUndo => _undoActions.isNotEmpty;
  bool get canRedo => _redoActions.isNotEmpty;

  /// Vector stroke eraser: deletes any stroke intersected by [position] within [eraserRadius].
  bool eraseAt(Offset position) {
    bool erasedAny = false;
    for (int i = _strokes.length - 1; i >= 0; i--) {
      final s = _strokes[i];
      final threshold = _eraserRadius + s.baseWidth * 0.5;
      if (!s.bounds.inflate(threshold).contains(position)) {
        continue;
      }
      if (s.points.isEmpty) continue;

      bool hit = false;
      if (s.points.length == 1) {
        final d2 = (s.points.first.position.dx - position.dx) *
                (s.points.first.position.dx - position.dx) +
            (s.points.first.position.dy - position.dy) *
                (s.points.first.position.dy - position.dy);
        hit = d2 <= threshold * threshold;
      } else {
        final thresholdSq = threshold * threshold;
        for (int j = 0; j < s.points.length - 1; j++) {
          final a = s.points[j].position;
          final b = s.points[j + 1].position;
          final abX = b.dx - a.dx;
          final abY = b.dy - a.dy;
          final apX = position.dx - a.dx;
          final apY = position.dy - a.dy;
          final lenSq = abX * abX + abY * abY;

          double t = 0.0;
          if (lenSq > 1e-6) {
            t = ((apX * abX + apY * abY) / lenSq).clamp(0.0, 1.0);
          }
          final projX = a.dx + t * abX;
          final projY = a.dy + t * abY;
          final distX = position.dx - projX;
          final distY = position.dy - projY;

          if (distX * distX + distY * distY <= thresholdSq) {
            hit = true;
            break;
          }
        }
      }

      if (hit) {
        final removed = _strokes.removeAt(i);
        _undoActions.add(CanvasAction(CanvasActionType.removeStroke, removed, i));
        _redoActions.clear();
        erasedAny = true;
      }
    }
    return erasedAny;
  }

  /// Pointer down event ingestion
  void handlePointerDown(PointerSample sample) {
    if (_stylusOnlyDrawing && sample.deviceType == PointerDeviceKind.touch) {
      return;
    }

    if (_activeTool == CanvasTool.eraser) {
      if (eraseAt(sample.position)) {
        _staticRepaintNotifier.notify();
      }
      notifyListeners();
      return;
    }

    final stroke = _pointerInput.onPointerDown(
      sample,
      color: _activeColor,
      width: _activeWidth,
    );
    if (stroke != null) {
      if (stroke.isComplete) {
        _strokes.add(stroke);
        _undoActions.add(CanvasAction(CanvasActionType.addStroke, stroke));
        _redoActions.clear();
        final rep = _pointerInput.lastBenchmarkReport;
        if (rep != null) {
          _benchmarkHistory.add(rep);
        }
        _staticRepaintNotifier.notify();
      }
      _activeRepaintNotifier.notify();
      notifyListeners();
    }
  }

  /// Pointer move event ingestion
  void handlePointerMove(PointerSample sample) {
    if (_stylusOnlyDrawing && sample.deviceType == PointerDeviceKind.touch) {
      return;
    }

    if (_activeTool == CanvasTool.eraser) {
      if (eraseAt(sample.position)) {
        _staticRepaintNotifier.notify();
      }
      notifyListeners();
      return;
    }

    final stroke = _pointerInput.onPointerMove(sample);
    if (stroke != null) {
      _activeRepaintNotifier.notify();
      notifyListeners();
    }
  }

  /// Pointer up event ingestion
  void handlePointerUp(PointerSample sample) {
    if (_stylusOnlyDrawing && sample.deviceType == PointerDeviceKind.touch) {
      return;
    }

    if (_activeTool == CanvasTool.eraser) {
      if (eraseAt(sample.position)) {
        _staticRepaintNotifier.notify();
      }
      notifyListeners();
      return;
    }

    final completedStroke = _pointerInput.onPointerUp(sample);
    if (completedStroke != null) {
      _strokes.add(completedStroke);
      _undoActions.add(CanvasAction(CanvasActionType.addStroke, completedStroke));
      _redoActions.clear();
      final rep = _pointerInput.lastBenchmarkReport;
      if (rep != null) {
        _benchmarkHistory.add(rep);
      }
      _staticRepaintNotifier.notify();
      _activeRepaintNotifier.notify();
      notifyListeners();
    }
  }

  /// Pointer cancel event ingestion
  void handlePointerCancel(PointerSample sample) {
    _pointerInput.onPointerCancel(sample);
    _activeRepaintNotifier.notify();
    notifyListeners();
  }

  /// Reverts the most recent action (stroke drawn or erased).
  void undo() {
    if (_undoActions.isEmpty) return;
    final action = _undoActions.removeLast();
    if (action.type == CanvasActionType.addStroke) {
      _strokes.remove(action.stroke);
      _redoActions.add(action);
    } else if (action.type == CanvasActionType.removeStroke) {
      if (action.index >= 0 && action.index <= _strokes.length) {
        _strokes.insert(action.index, action.stroke);
      } else {
        _strokes.add(action.stroke);
      }
      _redoActions.add(action);
    }
    _staticRepaintNotifier.notify();
    _activeRepaintNotifier.notify();
    notifyListeners();
  }

  /// Reapplies the most recently reverted action.
  void redo() {
    if (_redoActions.isEmpty) return;
    final action = _redoActions.removeLast();
    if (action.type == CanvasActionType.addStroke) {
      _strokes.add(action.stroke);
      _undoActions.add(action);
    } else if (action.type == CanvasActionType.removeStroke) {
      _strokes.remove(action.stroke);
      _undoActions.add(action);
    }
    _staticRepaintNotifier.notify();
    _activeRepaintNotifier.notify();
    notifyListeners();
  }

  /// Clears all strokes on the canvas and history stacks.
  void clear() {
    if (_strokes.isEmpty && _undoActions.isEmpty && !isDrawing) return;
    _strokes.clear();
    _undoActions.clear();
    _redoActions.clear();
    _pointerInput.reset();
    _staticRepaintNotifier.notify();
    _activeRepaintNotifier.notify();
    notifyListeners();
  }
}

/// Package-level alias for [KidzCanvasController].
typedef GoPaintController = KidzCanvasController;
