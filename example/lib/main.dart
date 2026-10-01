import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_paint/go_paint.dart';
import 'geometry_debugger_screen.dart';

void main() {
  runApp(const KidzCanvasBenchmarkApp());
}

/// Metadata describing host platform, hardware, display, and architecture.
class PlatformBenchmarkMetadata {
  final String platform;
  final String? androidVersion;
  final String device;
  final String? cpuArchitecture;
  final double? refreshRate;
  final double devicePixelRatio;
  final String screenResolution;

  const PlatformBenchmarkMetadata({
    this.platform = 'unknown',
    this.androidVersion,
    this.device = 'Unknown Device',
    this.cpuArchitecture,
    this.refreshRate,
    this.devicePixelRatio = 1.0,
    this.screenResolution = 'unknown',
  });

  /// Safely resolves device and platform metadata without fabricating refresh rate.
  static Future<PlatformBenchmarkMetadata> resolve(BuildContext context) async {
    String platformName = defaultTargetPlatform.name.toLowerCase();
    String? androidVer;
    String deviceDesc = 'Unknown Device';
    String? cpuArch;

    // Extract context properties synchronously before any async gap
    double? detectedRefreshRate;
    try {
      final view = View.maybeOf(context);
      final rate = view?.display.refreshRate;
      if (rate != null && rate > 0) {
        detectedRefreshRate = rate;
      }
    } catch (_) {}

    final mediaQuery = MediaQuery.maybeOf(context);
    final pixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final size = mediaQuery?.size ?? Size.zero;
    final screenRes = size != Size.zero
        ? '${(size.width * pixelRatio).toInt()}x${(size.height * pixelRatio).toInt()} physical (${size.width.toInt()}x${size.height.toInt()} logical)'
        : 'unknown';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (!kIsWeb && Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        platformName = 'android';
        androidVer =
            '${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        deviceDesc = (manufacturer.isNotEmpty &&
                !model.toLowerCase().startsWith(manufacturer.toLowerCase()))
            ? '$manufacturer $model'
            : model;
        if (androidInfo.supportedAbis.isNotEmpty) {
          cpuArch = androidInfo.supportedAbis.first;
        }
      } else if (!kIsWeb && Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        platformName = 'macos';
        deviceDesc = '${macInfo.model} (${macInfo.osRelease})';
        cpuArch = macInfo.arch;
      } else if (!kIsWeb && Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        platformName = 'ios';
        deviceDesc = '${iosInfo.name} ${iosInfo.model}';
      } else {
        deviceDesc = defaultTargetPlatform.name;
      }
    } catch (_) {
      platformName = defaultTargetPlatform.name.toLowerCase();
      deviceDesc = kIsWeb
          ? 'Web'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }

    return PlatformBenchmarkMetadata(
      platform: platformName,
      androidVersion: androidVer,
      device: deviceDesc,
      cpuArchitecture: cpuArch,
      refreshRate: detectedRefreshRate,
      devicePixelRatio: pixelRatio,
      screenResolution: screenRes,
    );
  }
}

/// The official v0.3 / v0.4 Benchmarking & Geometry Debugger App.
class KidzCanvasBenchmarkApp extends StatefulWidget {
  const KidzCanvasBenchmarkApp({super.key});

  @override
  State<KidzCanvasBenchmarkApp> createState() => _KidzCanvasBenchmarkAppState();
}

class _KidzCanvasBenchmarkAppState extends State<KidzCanvasBenchmarkApp> {
  int _currentTab = 0; // Default to Input & Brush Benchmark for v0.5

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GO Engine Benchmark & Geometry Debugger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _currentTab,
          children: const [
            BenchmarkScreen(),
            GeometryDebuggerScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (idx) => setState(() => _currentTab = idx),
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF38BDF8),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed, color: Colors.white70),
              selectedIcon: Icon(Icons.speed, color: Colors.black),
              label: 'Input Benchmark',
            ),
            NavigationDestination(
              icon: Icon(Icons.polyline, color: Colors.white70),
              selectedIcon: Icon(Icons.polyline, color: Colors.black),
              label: 'Geometry Debugger',
            ),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum BenchmarkMode {
  slowHandwriting('Slow handwriting', 'slow_handwriting',
      'Cursive letterforms & loops', Icons.edit),
  fastScribble('Fast scribble', 'fast_scribble', 'Rapid side-to-side sweeping',
      Icons.bolt),
  circle('Circle', 'circle', 'Continuous curvature & symmetry',
      Icons.circle_outlined),
  sharpCorners('Sharp corners', 'sharp_corners', 'Apexes, M/N/Z turns & stars',
      Icons.change_history),
  zigzag(
      'Zig-zag', 'zigzag', 'High-frequency triangular wave', Icons.show_chart),
  longLine('Long straight line', 'long_straight_line',
      'Drift & steady-state stability', Icons.linear_scale),
  tinyDetail('Tiny detail', 'tiny_detail', 'Sub-millimeter stipples & accents',
      Icons.grain),
  rapidDirection('Rapid direction changes', 'rapid_direction_changes',
      '180° hairpin reversals', Icons.alt_route);

  final String title;
  final String testId;
  final String description;
  final IconData icon;
  const BenchmarkMode(this.title, this.testId, this.description, this.icon);
}

enum ActiveBrush {
  crayon('Crayon (v0.5.1)', Icons.color_lens),
  pencil('Pencil (v0.5)', Icons.edit),
  basicInk('Basic Ink (v0.1)', Icons.brush),
  outlineInk('Outline (v0.4)', Icons.polyline);

  final String label;
  final IconData icon;
  const ActiveBrush(this.label, this.icon);
}

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  late final KidzCanvasController _controller;

  // Active Brush Engine (Crayon default for v0.5.1)
  ActiveBrush _activeBrush = ActiveBrush.crayon;
  bool _pencilLeadGrain = true;
  bool _pencilGraphiteHalo = true;
  bool _pencilPaperTooth = true;
  double _pencilLeadGrade = 0.3; // 0.1, 0.3, 0.5
  bool _showPencilHUD = true;

  // Crayon state
  bool _crayonEdgeVariation = true;
  bool _crayonEdgeFringe = true;
  bool _showCrayonHUD = true;

  // Diagnostics Toggles
  bool _showRawPoints = true;
  bool _showStabilizedPoints = true;
  bool _showCatmullPoints = true;
  bool _showPredictedTip = true;
  bool _showTemplateGuide = true;
  bool _showInstructions = true;

  // Current Benchmark Test Mode
  BenchmarkMode _activeMode = BenchmarkMode.slowHandwriting;

  // Platform Telemetry
  PlatformBenchmarkMetadata _platformMeta = const PlatformBenchmarkMetadata();

  // Baseline Stabilizer Config (prediction disabled for clean baseline)
  StabilizerConfig _config = const StabilizerConfig(
    minDistance: 1.5,
    velocityMin: 120.0,
    velocityMax: 800.0,
    streamlineSlow: 0.45,
    streamlineFast: 0.08,
    cornerAngleDeg: 65.0,
    cornerSmoothingFactor: 0.12,
    predictionEnabled: false,
    predictionHorizonMs: 16.0,
    maxPredictionDistance: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _controller = KidzCanvasController(
      initialColor: const Color(0xFFE11D48), // Vibrant crayon crimson
      initialWidth: 12.0,
      strokeRenderer: CrayonRenderer(
        CrayonConfig(
          enableEdgeVariation: _crayonEdgeVariation,
          enableEdgeFringe: _crayonEdgeFringe,
        ),
      ),
      pointerInput: PointerInput(
        stabilizer: Stabilizer(config: _config),
        multiTouchPolicy: MultiTouchPolicy.completeCurrentStroke,
      ),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initPlatformMetadata());
  }

  void _updateBrushRenderer() {
    switch (_activeBrush) {
      case ActiveBrush.crayon:
        _controller.activeWidth = 12.0;
        _controller.strokeRenderer = CrayonRenderer(
          CrayonConfig(
            enableEdgeVariation: _crayonEdgeVariation,
            enableEdgeFringe: _crayonEdgeFringe,
          ),
        );
        break;
      case ActiveBrush.pencil:
        double baseW = 3.0;
        double baseOp = 0.70;
        if (_pencilLeadGrade == 0.1) {
          baseW = 1.6;
          baseOp = 0.50;
        } else if (_pencilLeadGrade == 0.5) {
          baseW = 5.5;
          baseOp = 0.85;
        }
        _controller.activeWidth = baseW;
        if (_controller.activeColor == const Color(0xFFE11D48)) {
          _controller.activeColor =
              const Color(0xFF262626); // Graphite charcoal
        }
        _controller.strokeRenderer = PencilRenderer(
          PencilConfig(
            baseOpacity: baseOp,
            enableLeadGrain: _pencilLeadGrain,
            enableGraphiteHalo: _pencilGraphiteHalo,
            enablePaperTooth: _pencilPaperTooth,
          ),
        );
        break;

      case ActiveBrush.basicInk:
        _controller.activeWidth = 4.0;
        _controller.strokeRenderer = const BasicInkRenderer();
        break;
      case ActiveBrush.outlineInk:
        _controller.activeWidth = 8.0;
        _controller.strokeRenderer = const OutlineInkRenderer(
          fillOutline: true,
          showOutline: false,
        );
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initPlatformMetadata();
  }

  Future<void> _initPlatformMetadata() async {
    if (!mounted) return;
    final meta = await PlatformBenchmarkMetadata.resolve(context);
    if (!mounted) return;
    setState(() {
      _platformMeta = meta;
    });
    _syncBenchmarkContext();
  }

  void _syncBenchmarkContext() {
    _controller.setBenchmarkContext(
      testMode: _activeMode.testId,
      platform: _platformMeta.platform,
      androidVersion: _platformMeta.androidVersion,
      device: _platformMeta.device,
      cpuArchitecture: _platformMeta.cpuArchitecture,
      refreshRate: _platformMeta.refreshRate,
      devicePixelRatio: _platformMeta.devicePixelRatio,
      screenResolution: _platformMeta.screenResolution,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyConfig(StabilizerConfig newConfig) {
    setState(() {
      _config = newConfig;
      _controller.updateConfig(newConfig);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GO Engine (go_paint) Benchmark',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${_platformMeta.device} • ${_platformMeta.platform.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showInstructions ? Icons.info : Icons.info_outline),
            tooltip: 'Benchmark Protocol Instructions',
            onPressed: () =>
                setState(() => _showInstructions = !_showInstructions),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Tuner & Diagnostics Settings',
            onPressed: _openTunerBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Benchmark Results (JSON)',
            onPressed: _openExportBenchmarkModal,
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed:
                      _controller.canUndo ? () => _controller.undo() : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  onPressed:
                      _controller.canRedo ? () => _controller.redo() : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear',
                  onPressed: _controller.strokes.isNotEmpty
                      ? () => _controller.clear()
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Template Guide Background
          if (_showTemplateGuide)
            Positioned.fill(
              child: CustomPaint(
                painter: _TemplateGuidePainter(mode: _activeMode),
              ),
            ),

          // 2. Interactive Drawing Canvas
          Positioned.fill(
            child: KidzCanvas(
              controller: _controller,
              backgroundColor: Colors.transparent,
            ),
          ),

          // 3. Visual Diagnostics Overlay (Raw, Stabilized, Catmull, Predicted Tip)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DiagnosticsOverlayPainter(
                      diagnostics: _controller.diagnostics,
                      lastReport: _controller.lastBenchmarkReport,
                      showRaw: _showRawPoints,
                      showStabilized: _showStabilizedPoints,
                      showCatmull: _showCatmullPoints,
                      showPredictedTip: _showPredictedTip,
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Floating Real-Time Telemetry HUD (Top Left)
          Positioned(
            top: 10,
            left: 10,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final diag = _controller.diagnostics;
                return _buildTelemetryHUD(diag);
              },
            ),
          ),

          // 4b. Floating Crayon Debug HUD (Top Left, below Telemetry HUD)
          if (_activeBrush == ActiveBrush.crayon && _showCrayonHUD)
            Positioned(
              top: 175,
              left: 10,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _buildCrayonHUD(),
              ),
            ),

          // 4c. Floating Pencil Debug HUD (Top Left, below Telemetry HUD)
          if (_activeBrush == ActiveBrush.pencil && _showPencilHUD)
            Positioned(
              top: 175,
              left: 10,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _buildPencilHUD(),
              ),
            ),

          // 5. Android Benchmark Instruction Protocol Panel (Top Right, Collapsible)
          if (_showInstructions)
            Positioned(
              top: 10,
              right: 10,
              child: _buildInstructionPanel(),
            ),

          // 6. Test Mode Template Selector & Diagnostics Toggles (Bottom Bar)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: SafeArea(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                color: Colors.white.withValues(alpha: 0.96),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brush Selector Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Brush: ',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                            ...ActiveBrush.values.map((brush) {
                              final isSel = _activeBrush == brush;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  selected: isSel,
                                  avatar: Icon(brush.icon, size: 14),
                                  label: Text(brush.label,
                                      style: const TextStyle(fontSize: 10.5)),
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() {
                                        _activeBrush = brush;
                                        _updateBrushRenderer();
                                      });
                                    }
                                  },
                                ),
                              );
                            }),
                            if (_activeBrush == ActiveBrush.crayon) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: Icon(
                                    _showCrayonHUD
                                        ? Icons.analytics
                                        : Icons.analytics_outlined,
                                    size: 18),
                                tooltip: 'Toggle Crayon Debug HUD',
                                onPressed: () => setState(
                                    () => _showCrayonHUD = !_showCrayonHUD),
                              ),
                            ],
                            if (_activeBrush == ActiveBrush.pencil) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: Icon(
                                    _showPencilHUD
                                        ? Icons.analytics
                                        : Icons.analytics_outlined,
                                    size: 18),
                                tooltip: 'Toggle Pencil Debug HUD',
                                onPressed: () => setState(
                                    () => _showPencilHUD = !_showPencilHUD),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 6, thickness: 0.5),

                      // Mode Selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: BenchmarkMode.values.map((mode) {
                            final isSelected = _activeMode == mode;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: FilterChip(
                                selected: isSelected,
                                avatar: Icon(mode.icon, size: 15),
                                label: Text(mode.title,
                                    style: const TextStyle(fontSize: 11.5)),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _activeMode = mode);
                                    _syncBenchmarkContext();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Diagnostics quick toggles
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniToggle('Raw', _showRawPoints,
                              (v) => setState(() => _showRawPoints = v)),
                          _buildMiniToggle('Smooth', _showStabilizedPoints,
                              (v) => setState(() => _showStabilizedPoints = v)),
                          _buildMiniToggle('Catmull', _showCatmullPoints,
                              (v) => setState(() => _showCatmullPoints = v)),
                          _buildMiniToggle('Predict', _showPredictedTip,
                              (v) => setState(() => _showPredictedTip = v)),
                          _buildMiniToggle('Guide', _showTemplateGuide,
                              (v) => setState(() => _showTemplateGuide = v)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 14, color: value ? Colors.blue : Colors.grey),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: value ? Colors.black87 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// Collapsible instruction card setting expectations for clean Android testing.
  Widget _buildInstructionPanel() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Colors.blueGrey),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Android Protocol',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _showInstructions = false),
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('• Use one finger.',
              style: TextStyle(fontSize: 10, color: Colors.black87)),
          const Text('• Draw naturally.',
              style: TextStyle(fontSize: 10, color: Colors.black87)),
          const Text('• Do not compensate for smoothing.',
              style: TextStyle(fontSize: 10, color: Colors.black87)),
          const Text('• Repeat each test 3–5 times.',
              style: TextStyle(fontSize: 10, color: Colors.black87)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Prediction: OFF (Baseline)',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  /// Floating HUD displaying real-time Crayon 120 Hz incremental pipeline telemetry.
  Widget _buildCrayonHUD() {
    final stroke = _controller.activeStroke ??
        (_controller.strokes.isNotEmpty ? _controller.strokes.last : null);
    final lastPt =
        stroke?.points.isNotEmpty == true ? stroke!.points.last : null;

    final curVel = lastPt?.velocity ?? 0.0;
    final curPress = lastPt?.pressure ?? 0.0;

    CrayonIncrementalTelemetry telem = const CrayonIncrementalTelemetry();
    double curOpacity = 0.90;
    double curWidth = 0.0;

    if (_controller.strokeRenderer is CrayonRenderer) {
      final crayon = _controller.strokeRenderer as CrayonRenderer;
      telem = crayon.telemetry;
      if (stroke != null) {
        curOpacity = crayon.computeOpacity(stroke);
        final radii = crayon.computePointRadii(stroke);
        curWidth = radii.isNotEmpty ? radii.last * 2.0 : 0.0;
      }
    }

    final totalColor = telem.totalTimeMs < 8.33
        ? Colors.greenAccent
        : telem.totalTimeMs < 16.67
            ? Colors.amberAccent
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            const Color(0xFF1E1B4B).withValues(alpha: 0.94), // Deep wax indigo
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color:
                const Color(0xFFF43F5E).withValues(alpha: 0.6)), // Crayon rose
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.color_lens, color: Color(0xFFFB7185), size: 13),
              const SizedBox(width: 5),
              const Text('CRAYON HUD (v0.5.2)',
                  style: TextStyle(
                      color: Color(0xFFFB7185),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() {
                  _crayonEdgeVariation = !_crayonEdgeVariation;
                  _updateBrushRenderer();
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _crayonEdgeVariation
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _crayonEdgeVariation ? Colors.green : Colors.red,
                        width: 0.8),
                  ),
                  child: Text(
                    _crayonEdgeVariation ? 'Tooth: ON' : 'Tooth: OFF',
                    style: TextStyle(
                        color: _crayonEdgeVariation
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 9.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() {
                  _crayonEdgeFringe = !_crayonEdgeFringe;
                  _updateBrushRenderer();
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _crayonEdgeFringe
                        ? Colors.cyan.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _crayonEdgeFringe ? Colors.cyan : Colors.grey,
                        width: 0.8),
                  ),
                  child: Text(
                    _crayonEdgeFringe ? 'Fringe: ON' : 'Fringe: OFF',
                    style: TextStyle(
                        color: _crayonEdgeFringe
                            ? Colors.cyanAccent
                            : Colors.white70,
                        fontSize: 9.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
              'Width:   ${curWidth.toStringAsFixed(2)} px | Vel: ${curVel.toStringAsFixed(0)} px/s',
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
          Text(
              'Press:   ${curPress.toStringAsFixed(2)} | Pigment: ${(curOpacity * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Color(0xFFFDE047),
                  fontSize: 10,
                  fontFamily: 'monospace')),
          const Divider(height: 6, thickness: 0.5, color: Colors.white24),
          Text('Width Update:    ${telem.widthTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text('Geom Increm:     ${telem.geometryTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text('Tooth Perturb:   ${telem.contourTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text(
              'Draw Submission: ${telem.drawSubmissionTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text('Active Total:    ${telem.totalTimeMs.toStringAsFixed(2)} ms',
              style: TextStyle(
                  color: totalColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const Divider(height: 6, thickness: 0.5, color: Colors.white24),
          Text(
              'p50: ${telem.p50TotalMs.toStringAsFixed(2)} ms | p95: ${telem.p95TotalMs.toStringAsFixed(2)} ms | max: ${telem.maxTotalMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text(
              'Points: ${telem.pointCount} | Contour Verts: ${telem.contourVertexCount}',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  /// Floating HUD displaying real-time Pencil brush dynamics and diagnostics.
  Widget _buildPencilHUD() {
    final stroke = _controller.activeStroke ??
        (_controller.strokes.isNotEmpty ? _controller.strokes.last : null);
    final lastPt =
        stroke?.points.isNotEmpty == true ? stroke!.points.last : null;

    double curWidth = 0.0;
    double curVel = lastPt?.velocity ?? 0.0;
    double curPress = lastPt?.pressure ?? 0.0;
    double curOpacity = 0.65;

    PencilIncrementalTelemetry telem = const PencilIncrementalTelemetry();
    if (_controller.strokeRenderer is PencilRenderer) {
      final renderer = _controller.strokeRenderer as PencilRenderer;
      telem = renderer.telemetry;
      if (stroke != null && stroke.points.isNotEmpty) {
        final radii = renderer.computePointRadii(stroke);
        curWidth = radii.isNotEmpty ? radii.last * 2.0 : 0.0;
        curOpacity = renderer.computeOpacity(stroke);
      }
    }

    final totalColor = telem.totalTimeMs <= 4.0
        ? Colors.greenAccent
        : (telem.totalTimeMs <= 8.33 ? Colors.yellowAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit, color: Color(0xFF38BDF8), size: 13),
              const SizedBox(width: 5),
              const Text('PENCIL HUD',
                  style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() {
                  _pencilPaperTooth = !_pencilPaperTooth;
                  _updateBrushRenderer();
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pencilPaperTooth
                        ? Colors.amber.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _pencilPaperTooth ? Colors.amber : Colors.grey,
                        width: 0.8),
                  ),
                  child: Text(
                    _pencilPaperTooth ? 'Tooth: ON' : 'Tooth: OFF',
                    style: TextStyle(
                        color: _pencilPaperTooth
                            ? Colors.amberAccent
                            : Colors.white70,
                        fontSize: 9.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() {
                  _pencilLeadGrain = !_pencilLeadGrain;
                  _updateBrushRenderer();
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pencilLeadGrain
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _pencilLeadGrain ? Colors.green : Colors.red,
                        width: 0.8),
                  ),
                  child: Text(
                    _pencilLeadGrain ? 'Grain: ON' : 'Grain: OFF',
                    style: TextStyle(
                        color: _pencilLeadGrain
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 9.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() {
                  _pencilGraphiteHalo = !_pencilGraphiteHalo;
                  _updateBrushRenderer();
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pencilGraphiteHalo
                        ? Colors.cyan.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _pencilGraphiteHalo ? Colors.cyan : Colors.grey,
                        width: 0.8),
                  ),
                  child: Text(
                    _pencilGraphiteHalo ? 'Halo: ON' : 'Halo: OFF',
                    style: TextStyle(
                        color: _pencilGraphiteHalo
                            ? Colors.cyanAccent
                            : Colors.white70,
                        fontSize: 9.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lead Grade: ',
                  style: TextStyle(color: Colors.white70, fontSize: 10)),
              _buildPencilGradeButton('0.1 Fine', 0.1),
              const SizedBox(width: 4),
              _buildPencilGradeButton('0.3 Mid', 0.3),
              const SizedBox(width: 4),
              _buildPencilGradeButton('0.5 Bold', 0.5),
            ],
          ),
          const SizedBox(height: 5),
          Text(
              'Width:   ${curWidth.toStringAsFixed(2)} px | Vel: ${curVel.toStringAsFixed(0)} px/s',
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
          Text(
              'Press:   ${curPress.toStringAsFixed(2)} | Lead: ${(curOpacity * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 10,
                  fontFamily: 'monospace')),
          const Divider(height: 6, thickness: 0.5, color: Colors.white24),
          Text('Width Update:    ${telem.widthTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text('Geom Increm:     ${telem.geometryTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text('Grain Perturb:   ${telem.contourTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text(
              'Draw Submission: ${telem.drawSubmissionTimeMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text('Active Total:    ${telem.totalTimeMs.toStringAsFixed(2)} ms',
              style: TextStyle(
                  color: totalColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const Divider(height: 6, thickness: 0.5, color: Colors.white24),
          Text(
              'p50: ${telem.p50TotalMs.toStringAsFixed(2)} ms | p95: ${telem.p95TotalMs.toStringAsFixed(2)} ms | max: ${telem.maxTotalMs.toStringAsFixed(2)} ms',
              style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
          Text(
              'Points: ${telem.pointCount} | Contour Verts: ${telem.contourVertexCount}',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9.5,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildPencilGradeButton(String label, double grade) {
    final isSelected = _pencilLeadGrade == grade;
    return InkWell(
      onTap: () => setState(() {
        _pencilLeadGrade = grade;
        _updateBrushRenderer();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
              : Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Real-time HUD displaying all Section 8 requirements and multi-touch indicator.

  Widget _buildTelemetryHUD(StrokeDiagnostics diag) {
    final devKindStr = diag.deviceKind == PointerDeviceKind.stylus
        ? '🖊️ Stylus'
        : diag.deviceKind == PointerDeviceKind.mouse
            ? '🖱️ Mouse'
            : '👆 Finger';

    final isMultitouch = diag.activePointerCount > 1;
    final stateStr = isMultitouch
        ? '⚠️ MULTITOUCH (${diag.activePointerCount} fingers)'
        : _controller.isDrawing
            ? 'DRAWING (1 finger)'
            : 'IDLE';

    final lastReport = _controller.lastBenchmarkReport;
    final dtDisplay = lastReport != null
        ? '${lastReport.averageDeltaMs.toStringAsFixed(1)} ms'
        : '-- ms';

    final smoothingDisplay = _controller.isDrawing
        ? _config.streamlineSlow.toStringAsFixed(2)
        : (lastReport != null
            ? lastReport.smoothingAmount.toStringAsFixed(3)
            : _config.streamlineSlow.toStringAsFixed(2));

    final refreshDisplay = _platformMeta.refreshRate != null
        ? '${_platformMeta.refreshRate!.roundToDouble() == _platformMeta.refreshRate ? _platformMeta.refreshRate!.toInt() : _platformMeta.refreshRate!.toStringAsFixed(1)} Hz'
        : 'unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMultitouch
            ? const Color(0xFFC62828).withValues(alpha: 0.90)
            : Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        border: isMultitouch
            ? Border.all(color: Colors.redAccent, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stateStr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMultitouch
                      ? Colors.white
                      : (_controller.isDrawing
                          ? Colors.greenAccent
                          : Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              Text(devKindStr,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          if (isMultitouch) ...[
            const SizedBox(height: 2),
            const Text(
              'Secondary finger locked (stroke preserved)',
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.yellowAccent,
                  fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Device: ${_platformMeta.device} ($refreshDisplay)',
            style: const TextStyle(fontSize: 9.5, color: Colors.white70),
          ),
          Text(
            'Velocity: ${diag.currentVelocity.toStringAsFixed(0)} px/s',
            style: const TextStyle(
                fontSize: 10.5,
                color: Colors.amberAccent,
                fontFamily: 'monospace'),
          ),
          Text(
            'Pressure: ${(diag.currentPressure * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                fontSize: 10.5,
                color: Colors.cyanAccent,
                fontFamily: 'monospace'),
          ),
          Text(
            'Points: ${diag.rawPoints.length} raw | ${diag.stabilizedPoints.length} smooth | ${diag.catmullPoints.length} spline',
            style: const TextStyle(
                fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
          ),
          Text(
            'Sampling Δt: $dtDisplay | Smoothing: $smoothingDisplay',
            style: const TextStyle(
                fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
          ),
          Text(
            _config.predictionEnabled
                ? 'Prediction: ACTIVE (+1 frame)'
                : 'Prediction: OFF (Baseline)',
            style: TextStyle(
              fontSize: 10,
              color: _config.predictionEnabled
                  ? Colors.lightGreenAccent
                  : Colors.white60,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_controller.isDrawing && lastReport != null) ...[
            const Divider(color: Colors.white24, height: 8),
            Text(
              'Last [${lastReport.test}]: avg ${lastReport.averageVelocity.toStringAsFixed(0)} px/s | Δt ${lastReport.averageDeltaMs.toStringAsFixed(1)}ms',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Colors.greenAccent,
                  fontFamily: 'monospace'),
            ),
            Text(
              'Dev: corner ${lastReport.cornerDeviationPx != null ? "${lastReport.cornerDeviationPx!.toStringAsFixed(1)}px" : "none"} | avg ${lastReport.averageDeviationPx.toStringAsFixed(2)}px | max ${lastReport.maxDeviationPx.toStringAsFixed(1)}px',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Colors.cyanAccent,
                  fontFamily: 'monospace'),
            ),
            Text(
              'Est. Processing Lag: ${lastReport.estimatedProcessingLatencyMs.toStringAsFixed(1)} ms (filter group delay)',
              style: const TextStyle(fontSize: 9, color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }

  void _openTunerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('StabilizerConfig Tuner',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text(
                        'Calibrate thresholds directly on Android hardware',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const Divider(height: 24),

                    // Min Distance
                    _buildSlider(
                      'Min Distance (Noise Gate): ${_config.minDistance.toStringAsFixed(1)} px',
                      _config.minDistance,
                      0.5,
                      5.0,
                      (val) {
                        setSheetState(() {});
                        _applyConfig(_config.copyWith(minDistance: val));
                      },
                    ),

                    // Streamline Slow
                    _buildSlider(
                      'Streamline Slow (Handwriting Tremor): ${_config.streamlineSlow.toStringAsFixed(2)}',
                      _config.streamlineSlow,
                      0.0,
                      0.85,
                      (val) {
                        setSheetState(() {});
                        _applyConfig(_config.copyWith(streamlineSlow: val));
                      },
                    ),

                    // Streamline Fast
                    _buildSlider(
                      'Streamline Fast (Sweep Latency): ${_config.streamlineFast.toStringAsFixed(2)}',
                      _config.streamlineFast,
                      0.0,
                      0.40,
                      (val) {
                        setSheetState(() {});
                        _applyConfig(_config.copyWith(streamlineFast: val));
                      },
                    ),

                    // Corner Angle Deg
                    _buildSlider(
                      'Corner Angle Trigger: ${_config.cornerAngleDeg.toStringAsFixed(0)}°',
                      _config.cornerAngleDeg,
                      30.0,
                      120.0,
                      (val) {
                        setSheetState(() {});
                        _applyConfig(_config.copyWith(cornerAngleDeg: val));
                      },
                    ),

                    // Corner Smoothing Factor
                    _buildSlider(
                      'Corner Apex Smoothing: ${_config.cornerSmoothingFactor.toStringAsFixed(2)}',
                      _config.cornerSmoothingFactor,
                      0.02,
                      0.40,
                      (val) {
                        setSheetState(() {});
                        _applyConfig(
                            _config.copyWith(cornerSmoothingFactor: val));
                      },
                    ),

                    const Divider(height: 20),
                    // Prediction Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Point Prediction (Experimental)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text(
                          'Extrapolates 1-frame ahead to eliminate perceived touchscreen lag (keep OFF for baseline)',
                          style: TextStyle(fontSize: 11)),
                      value: _config.predictionEnabled,
                      onChanged: (enabled) {
                        setSheetState(() {});
                        _applyConfig(
                            _config.copyWith(predictionEnabled: enabled));
                      },
                    ),

                    if (_config.predictionEnabled) ...[
                      _buildSlider(
                        'Prediction Horizon: ${_config.predictionHorizonMs.toStringAsFixed(0)} ms',
                        _config.predictionHorizonMs,
                        8.0,
                        32.0,
                        (val) {
                          setSheetState(() {});
                          _applyConfig(
                              _config.copyWith(predictionHorizonMs: val));
                        },
                      ),
                      _buildSlider(
                        'Max Prediction Distance: ${_config.maxPredictionDistance.toStringAsFixed(0)} px',
                        _config.maxPredictionDistance,
                        5.0,
                        30.0,
                        (val) {
                          setSheetState(() {});
                          _applyConfig(
                              _config.copyWith(maxPredictionDistance: val));
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset Defaults (Baseline)'),
                      onPressed: () {
                        setSheetState(() {});
                        _applyConfig(const StabilizerConfig());
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openExportBenchmarkModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return _BenchmarkExportSheet(
          controller: _controller,
          activeMode: _activeMode,
          meta: _platformMeta,
        );
      },
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

enum ExportScope {
  latest('Latest Stroke'),
  summary('8 Tests Summary'),
  fullHistory('Session History');

  final String label;
  const ExportScope(this.label);
}

/// Modal bottom sheet displaying formatted benchmark JSON with copy-to-clipboard capabilities.
class _BenchmarkExportSheet extends StatefulWidget {
  final KidzCanvasController controller;
  final BenchmarkMode activeMode;
  final PlatformBenchmarkMetadata meta;

  const _BenchmarkExportSheet({
    required this.controller,
    required this.activeMode,
    required this.meta,
  });

  @override
  State<_BenchmarkExportSheet> createState() => _BenchmarkExportSheetState();
}

class _BenchmarkExportSheetState extends State<_BenchmarkExportSheet> {
  ExportScope _scope = ExportScope.latest;

  String _generateJsonString() {
    final history = widget.controller.benchmarkHistory;
    final latest = widget.controller.lastBenchmarkReport;

    if (_scope == ExportScope.latest) {
      if (latest == null) {
        final placeholder = {
          'notice':
              'No stroke recorded yet. Draw a stroke in any benchmark mode to collect real-device metrics.',
          'platform': widget.meta.platform,
          if (widget.meta.androidVersion != null)
            'androidVersion': widget.meta.androidVersion,
          'device': widget.meta.device,
          if (widget.meta.cpuArchitecture != null)
            'cpuArchitecture': widget.meta.cpuArchitecture,
          'refreshRate': widget.meta.refreshRate != null
              ? (widget.meta.refreshRate!.roundToDouble() ==
                      widget.meta.refreshRate
                  ? widget.meta.refreshRate!.toInt()
                  : widget.meta.refreshRate)
              : null,
          'devicePixelRatio': widget.meta.devicePixelRatio,
          'screenResolution': widget.meta.screenResolution,
          'currentMode': widget.activeMode.testId,
        };
        return const JsonEncoder.withIndent('  ').convert(placeholder);
      }
      return latest.toPrettyJson();
    }

    if (_scope == ExportScope.summary) {
      final Map<String, dynamic> testReports = {};
      for (final rep in history) {
        testReports[rep.test] = rep.toJson();
      }

      final summaryMap = {
        'platform': widget.meta.platform,
        if (widget.meta.androidVersion != null)
          'androidVersion': widget.meta.androidVersion,
        'device': widget.meta.device,
        if (widget.meta.cpuArchitecture != null)
          'cpuArchitecture': widget.meta.cpuArchitecture,
        'refreshRate': widget.meta.refreshRate != null
            ? (widget.meta.refreshRate!.roundToDouble() ==
                    widget.meta.refreshRate
                ? widget.meta.refreshRate!.toInt()
                : widget.meta.refreshRate)
            : null,
        'devicePixelRatio': widget.meta.devicePixelRatio,
        'screenResolution': widget.meta.screenResolution,
        'testedModesCount': testReports.length,
        'totalModes': BenchmarkMode.values.length,
        'tests': testReports,
      };
      return const JsonEncoder.withIndent('  ').convert(summaryMap);
    }

    // ExportScope.fullHistory
    final historyList = history.map((r) => r.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(historyList);
  }

  void _copyToClipboard(String jsonStr) {
    Clipboard.setData(ClipboardData(text: jsonStr));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text('Benchmark JSON copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jsonStr = _generateJsonString();
    final latest = widget.controller.lastBenchmarkReport;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Export Benchmark Results',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.meta.device} • ${widget.meta.refreshRate != null ? "${widget.meta.refreshRate!.toInt()} Hz" : "refresh rate unknown"}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scope Switcher
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ExportScope.values.map((scope) {
                final isSelected = _scope == scope;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: isSelected,
                    label:
                        Text(scope.label, style: const TextStyle(fontSize: 12)),
                    onSelected: (val) {
                      if (val) setState(() => _scope = scope);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Stat Badges (if latest exists)
          if (latest != null && _scope == ExportScope.latest)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatBadge('Velocity',
                        '${latest.averageVelocity.toStringAsFixed(0)} px/s'),
                    const SizedBox(width: 12),
                    _buildStatBadge('Avg Δt',
                        '${latest.averageDeltaMs.toStringAsFixed(1)} ms'),
                    const SizedBox(width: 12),
                    _buildStatBadge(
                        'Corner Dev',
                        latest.cornerDeviationPx != null
                            ? '${latest.cornerDeviationPx!.toStringAsFixed(1)} px'
                            : 'N/A'),
                    const SizedBox(width: 12),
                    _buildStatBadge('Avg Dev',
                        '${latest.averageDeviationPx.toStringAsFixed(2)} px'),
                    const SizedBox(width: 12),
                    _buildStatBadge('Max Dev',
                        '${latest.maxDeviationPx.toStringAsFixed(1)} px'),
                    const SizedBox(width: 12),
                    _buildStatBadge('Est. Filter Lag',
                        '${latest.estimatedProcessingLatencyMs.toStringAsFixed(1)} ms'),
                  ],
                ),
              ),
            ),

          // JSON Code Output Container
          Flexible(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Color(0xFF9CDCFE),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade900,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy JSON to Clipboard',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _copyToClipboard(jsonStr),
                ),
              ),
              if (widget.controller.benchmarkHistory.isNotEmpty) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Clear Session Benchmark History',
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      widget.controller.clearBenchmarkHistory();
                    });
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ],
    );
  }
}

/// Visual diagnostics painter rendering raw hardware samples, stabilized midpoints,
/// Catmull-Rom spline subdivisions, and the transient forward-predicted tip.
class _DiagnosticsOverlayPainter extends CustomPainter {
  final StrokeDiagnostics diagnostics;
  final StrokeBenchmarkReport? lastReport;
  final bool showRaw;
  final bool showStabilized;
  final bool showCatmull;
  final bool showPredictedTip;

  _DiagnosticsOverlayPainter({
    required this.diagnostics,
    this.lastReport,
    required this.showRaw,
    required this.showStabilized,
    required this.showCatmull,
    required this.showPredictedTip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Raw hardware digitizer path and points (Red)
    if (showRaw && diagnostics.rawPoints.isNotEmpty) {
      if (diagnostics.rawPoints.length >= 2) {
        final rawLinePaint = Paint()
          ..color = Colors.red.withValues(alpha: 0.35)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        final rawPath = Path()
          ..moveTo(
              diagnostics.rawPoints.first.dx, diagnostics.rawPoints.first.dy);
        for (int i = 1; i < diagnostics.rawPoints.length; i++) {
          rawPath.lineTo(
              diagnostics.rawPoints[i].dx, diagnostics.rawPoints[i].dy);
        }
        canvas.drawPath(rawPath, rawLinePaint);
      }

      final rawPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      for (final p in diagnostics.rawPoints) {
        canvas.drawCircle(p, 2.2, rawPaint);
      }
    }

    // 2. Stabilized centerline path and points (Blue)
    if (showStabilized && diagnostics.stabilizedPoints.isNotEmpty) {
      if (diagnostics.stabilizedPoints.length >= 2) {
        final smoothLinePaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.40)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final smoothPath = Path()
          ..moveTo(diagnostics.stabilizedPoints.first.dx,
              diagnostics.stabilizedPoints.first.dy);
        for (int i = 1; i < diagnostics.stabilizedPoints.length; i++) {
          smoothPath.lineTo(diagnostics.stabilizedPoints[i].dx,
              diagnostics.stabilizedPoints[i].dy);
        }
        canvas.drawPath(smoothPath, smoothLinePaint);
      }

      final smoothPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (final p in diagnostics.stabilizedPoints) {
        canvas.drawCircle(p, 3.4, smoothPaint);
      }
    }

    // 3. Catmull-Rom intermediate curve points (Amber dots)
    if (showCatmull && diagnostics.catmullPoints.isNotEmpty) {
      final catmullPaint = Paint()
        ..color = Colors.amber.shade700.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      for (final p in diagnostics.catmullPoints) {
        canvas.drawCircle(p, 1.8, catmullPaint);
      }
    }

    // 4. Detected Corner / Apex Overlay
    final corner = lastReport?.geometry?.corner;
    final rawApex = diagnostics.rawApex ?? corner?.rawApex;
    final procApex = diagnostics.processedApex ?? corner?.processedApex;

    if (corner?.detected == true && rawApex != null && procApex != null) {
      // Raw apex marker (red crosshair + circle)
      final apexPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(rawApex, 6.0, apexPaint);
      canvas.drawLine(rawApex - const Offset(8, 0),
          rawApex + const Offset(8, 0), apexPaint);
      canvas.drawLine(rawApex - const Offset(0, 8),
          rawApex + const Offset(0, 8), apexPaint);

      // Processed apex marker (cyan ring)
      final procApexPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(procApex, 6.0, procApexPaint);

      // Yellow deviation connector line
      final devLinePaint = Paint()
        ..color = Colors.yellowAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(rawApex, procApex, devLinePaint);

      // Apex deviation text badge
      final devPx = corner?.apexDeviationPx ?? (rawApex - procApex).distance;
      final angleStr = corner?.detectedAngleDeg != null
          ? '${corner!.detectedAngleDeg!.toStringAsFixed(0)}°'
          : '';
      final label = ' Apex Dev: ${devPx.toStringAsFixed(1)}px $angleStr ';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.yellowAccent,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, rawApex + const Offset(10, -12));
    }

    // 5. Best-Fit Straight Line (for long_straight_line mode)
    final straightLine = lastReport?.geometry?.straightLine;
    if (straightLine != null &&
        lastReport?.test == 'long_straight_line' &&
        diagnostics.rawPoints.length >= 2) {
      final linePaint = Paint()
        ..color = Colors.deepPurpleAccent.withValues(alpha: 0.65)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      final first = diagnostics.rawPoints.first;
      final last = diagnostics.rawPoints.last;
      canvas.drawLine(first, last, linePaint);
    }

    // 6. Fitted Circle (for circle mode)
    final circle = lastReport?.geometry?.circle;
    if (circle != null && lastReport?.test == 'circle') {
      final circlePaint = Paint()
        ..color = Colors.tealAccent.withValues(alpha: 0.6)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(circle.fittedCenter, circle.fittedRadius, circlePaint);
    }

    // 7. Predicted tip vector (Green ring + dashed forward vector)
    if (showPredictedTip &&
        diagnostics.predictedTip != null &&
        diagnostics.stabilizedPoints.isNotEmpty) {
      final tip = diagnostics.predictedTip!;
      final lastReal = diagnostics.stabilizedPoints.last;

      final vectorPaint = Paint()
        ..color = Colors.greenAccent.shade700
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(lastReal, tip, vectorPaint);

      final tipPaint = Paint()
        ..color = Colors.greenAccent.shade700
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tip, 4.0, tipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagnosticsOverlayPainter oldDelegate) => true;
}

/// Renders subtle dashed guide templates for the 8 standardized benchmark test modes.
class _TemplateGuidePainter extends CustomPainter {
  final BenchmarkMode mode;

  _TemplateGuidePainter({required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.22)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final cx = size.width * 0.5;
    final cy = size.height * 0.45;

    switch (mode) {
      case BenchmarkMode.slowHandwriting:
        // Cursive handwriting template ("hello")
        final path = Path()
          ..moveTo(cx - 140, cy)
          ..quadraticBezierTo(cx - 120, cy - 60, cx - 110, cy)
          ..quadraticBezierTo(cx - 95, cy - 25, cx - 80, cy)
          ..quadraticBezierTo(cx - 60, cy - 70, cx - 50, cy)
          ..quadraticBezierTo(cx - 30, cy - 70, cx - 20, cy)
          ..addOval(
              Rect.fromCircle(center: Offset(cx + 15, cy - 15), radius: 18));
        canvas.drawPath(path, paint);
        break;

      case BenchmarkMode.fastScribble:
        // Rapid horizontal sweeps
        final path = Path()..moveTo(cx - 130, cy - 60);
        for (int i = 0; i < 6; i++) {
          final y = cy - 60.0 + i * 24.0;
          path.lineTo(i.isEven ? cx + 130 : cx - 130, y);
        }
        canvas.drawPath(path, paint);
        break;

      case BenchmarkMode.circle:
        // Concentric circles
        canvas.drawCircle(Offset(cx, cy), 90, paint);
        canvas.drawCircle(Offset(cx, cy), 45, paint);
        break;

      case BenchmarkMode.sharpCorners:
        // Acute angle star / vertices
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final radOuter = i * (2 * math.pi / 5) - math.pi / 2;
          final radInner = radOuter + math.pi / 5;
          final pOuter = Offset(
              cx + 90 * math.cos(radOuter), cy + 90 * math.sin(radOuter));
          final pInner = Offset(
              cx + 40 * math.cos(radInner), cy + 40 * math.sin(radInner));
          if (i == 0) {
            path.moveTo(pOuter.dx, pOuter.dy);
          } else {
            path.lineTo(pOuter.dx, pOuter.dy);
          }
          path.lineTo(pInner.dx, pInner.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
        break;

      case BenchmarkMode.zigzag:
        // Sharp periodic triangular wave
        final path = Path()..moveTo(cx - 140, cy);
        for (int i = 0; i < 7; i++) {
          final x = cx - 140.0 + (i + 1) * 35.0;
          final y = i.isEven ? cy - 50.0 : cy + 50.0;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, paint);
        break;

      case BenchmarkMode.longLine:
        // Long diagonal straight line
        canvas.drawLine(
            Offset(cx - 140, cy - 120), Offset(cx + 140, cy + 120), paint);
        break;

      case BenchmarkMode.tinyDetail:
        // Tiny stipple circles and miniature loops
        for (int i = 0; i < 8; i++) {
          final offset = Offset(cx - 120.0 + i * 34.0, cy);
          canvas.drawCircle(offset, 4, paint);
          canvas.drawCircle(Offset(offset.dx, cy + 24), 8, paint);
        }
        break;

      case BenchmarkMode.rapidDirection:
        // 180° hairpin reversals
        final path = Path()
          ..moveTo(cx - 120, cy - 40)
          ..lineTo(cx + 120, cy - 40)
          ..arcToPoint(Offset(cx + 120, cy), radius: const Radius.circular(20))
          ..lineTo(cx - 120, cy)
          ..arcToPoint(Offset(cx - 120, cy + 40),
              radius: const Radius.circular(20), clockwise: false)
          ..lineTo(cx + 120, cy + 40);
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TemplateGuidePainter oldDelegate) =>
      oldDelegate.mode != mode;
}
