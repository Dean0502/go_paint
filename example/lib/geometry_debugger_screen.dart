import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_paint/go_paint.dart';

/// Geometry Debugger and Live Drawing Stress Test screen for GO Engine.
class GeometryDebuggerScreen extends StatefulWidget {
  const GeometryDebuggerScreen({super.key});

  @override
  State<GeometryDebuggerScreen> createState() => _GeometryDebuggerScreenState();
}

class _GeometryDebuggerScreenState extends State<GeometryDebuggerScreen>
    with SingleTickerProviderStateMixin {
  // Layer visibility toggles
  bool _outlineAlone = false;
  bool _showFill = true;
  bool _showOutlineBorder = true;
  bool _showLeftBoundary = true;
  bool _showRightBoundary = true;
  bool _showCenterline = true;
  bool _showVertices = true;
  bool _showBounds = true;

  // Geometry configuration
  double _strokeWidth = 16.0;
  StrokeCapType _cap = StrokeCapType.round;
  StrokeJoinType _join = StrokeJoinType.round;
  double _miterLimit = 4.0;
  bool _dynamicWidth = false;

  // Active stroke geometry
  List<StrokePoint> _activePoints = [];
  StrokeOutline? _activeOutline;
  double _lastGenTimeMs = 0.0;

  // Live Drawing Stress Test state
  bool _isStressTesting = false;
  Timer? _stressTimer;
  int _stressPointCount = 0;
  int _breach120HzCount = 0;
  int _breach60HzCount = 0;
  double _stressAngle = 0.0;
  double _stressRadius = 20.0;
  final Offset _stressCenter = const Offset(200, 300);

  // Selected preset test shape
  String _selectedShapeName = 'horizontal_line';

  @override
  void initState() {
    super.initState();
    _loadPresetShape('horizontal_line');
  }

  @override
  void dispose() {
    _stressTimer?.cancel();
    super.dispose();
  }

  void _rebuildGeometry() {
    if (_activePoints.isEmpty) {
      setState(() {
        _activeOutline = null;
        _lastGenTimeMs = 0.0;
      });
      return;
    }

    final sw = Stopwatch()..start();
    final profile = _dynamicWidth
        ? DynamicWidthProfile(StrokeWidthConfig(
            baseWidth: _strokeWidth,
            pressureEnabled: true,
            velocityEnabled: true,
            minWidthFactor: 0.5,
            maxWidthFactor: 1.8,
          ))
        : ConstantWidthProfile(_strokeWidth);

    final builder = StrokeGeometryBuilder(
      widthProfile: profile,
      cap: _cap,
      join: _join,
      miterLimit: _miterLimit,
      arcSteps: 8,
    );

    final outline =
        builder.buildFromPoints(_activePoints, baseWidth: _strokeWidth);
    sw.stop();

    final genMs = sw.elapsedMicroseconds / 1000.0;
    if (_isStressTesting) {
      if (genMs > 8.33) _breach120HzCount++;
      if (genMs > 16.67) _breach60HzCount++;
    }

    setState(() {
      _activeOutline = outline;
      _lastGenTimeMs = genMs;
    });
  }

  void _loadPresetShape(String shapeKey) {
    _stopStressTest();
    _selectedShapeName = shapeKey;

    final pts = <StrokePoint>[];
    switch (shapeKey) {
      case 'single_point_dab':
        pts.add(const StrokePoint(
            position: Offset(180, 260), timestamp: Duration.zero));
        break;
      case 'short_stroke':
        pts.add(const StrokePoint(
            position: Offset(180, 260), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(180.8, 260.4),
            timestamp: Duration(milliseconds: 16)));
        break;
      case 'horizontal_line':
        pts.add(const StrokePoint(
            position: Offset(50, 260), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(310, 260),
            timestamp: Duration(milliseconds: 100)));
        break;
      case 'vertical_line':
        pts.add(const StrokePoint(
            position: Offset(180, 100), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(180, 420),
            timestamp: Duration(milliseconds: 100)));
        break;
      case 'diagonal_line':
        pts.add(const StrokePoint(
            position: Offset(60, 140), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(300, 380),
            timestamp: Duration(milliseconds: 100)));
        break;
      case 'smooth_curve':
        for (int i = 0; i <= 40; i++) {
          final x = 40.0 + i * 7.0;
          final y = 260.0 + 70.0 * math.sin(i * 0.18);
          pts.add(StrokePoint(
            position: Offset(x, y),
            timestamp: Duration(milliseconds: i * 8),
            pressure: 0.4 + 0.6 * math.sin(i * 0.2),
            velocity: 300.0,
          ));
        }
        break;
      case 'full_circle':
        for (int i = 0; i <= 48; i++) {
          final a = i * 2 * math.pi / 48;
          pts.add(StrokePoint(
            position: Offset(180 + 90 * math.cos(a), 260 + 90 * math.sin(a)),
            timestamp: Duration(milliseconds: i * 8),
            pressure: 0.8,
            velocity: 400.0,
          ));
        }
        break;
      case '90_deg_corner':
        pts.add(const StrokePoint(
            position: Offset(60, 160), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(260, 160), timestamp: Duration(milliseconds: 50)));
        pts.add(const StrokePoint(
            position: Offset(260, 360),
            timestamp: Duration(milliseconds: 100)));
        break;
      case 'acute_corner':
        pts.add(const StrokePoint(
            position: Offset(60, 140), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(300, 260), timestamp: Duration(milliseconds: 50)));
        pts.add(const StrokePoint(
            position: Offset(70, 360), timestamp: Duration(milliseconds: 100)));
        break;
      case 'obtuse_corner':
        pts.add(const StrokePoint(
            position: Offset(60, 160), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(200, 260), timestamp: Duration(milliseconds: 50)));
        pts.add(const StrokePoint(
            position: Offset(320, 210),
            timestamp: Duration(milliseconds: 100)));
        break;
      case 'zigzag':
        for (int i = 0; i < 7; i++) {
          final x = 40.0 + i * 45.0;
          final y = (i % 2 == 0) ? 170.0 : 340.0;
          pts.add(StrokePoint(
            position: Offset(x, y),
            timestamp: Duration(milliseconds: i * 20),
            pressure: 0.7,
          ));
        }
        break;
      case 'rapid_direction_changes':
        const raw = [
          Offset(80, 180),
          Offset(110, 320),
          Offset(160, 190),
          Offset(210, 310),
          Offset(250, 180),
          Offset(290, 330),
        ];
        for (int i = 0; i < raw.length; i++) {
          pts.add(StrokePoint(
              position: raw[i], timestamp: Duration(milliseconds: i * 15)));
        }
        break;
      case 'pressure_width_variation':
        for (int i = 0; i <= 30; i++) {
          final x = 40.0 + i * 9.0;
          const y = 260.0;
          final p = (i <= 15) ? (i / 15.0) : (1.0 - (i - 15) / 15.0);
          pts.add(StrokePoint(
            position: Offset(x, y),
            timestamp: Duration(milliseconds: i * 8),
            pressure: p,
            velocity: 200.0,
          ));
        }
        _dynamicWidth = true;
        break;
      case 'duplicate_points':
        pts.add(const StrokePoint(
            position: Offset(80, 260), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(80, 260), timestamp: Duration(milliseconds: 8)));
        pts.add(const StrokePoint(
            position: Offset(80, 260), timestamp: Duration(milliseconds: 16)));
        pts.add(const StrokePoint(
            position: Offset(260, 260), timestamp: Duration(milliseconds: 50)));
        pts.add(const StrokePoint(
            position: Offset(260, 260), timestamp: Duration(milliseconds: 58)));
        break;
      case 'extremely_close_points':
        pts.add(const StrokePoint(
            position: Offset(80.0, 260.0), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(80.00003, 260.00002),
            timestamp: Duration(milliseconds: 8)));
        pts.add(const StrokePoint(
            position: Offset(260.0, 260.0),
            timestamp: Duration(milliseconds: 50)));
        break;
      case 'zero_width_stroke':
        pts.add(const StrokePoint(
            position: Offset(60, 200), timestamp: Duration.zero));
        pts.add(const StrokePoint(
            position: Offset(280, 280), timestamp: Duration(milliseconds: 50)));
        _strokeWidth = 0.0;
        break;
    }

    _activePoints = pts;
    _rebuildGeometry();
  }

  void _startStressTest() {
    _stressTimer?.cancel();
    _activePoints.clear();
    _stressPointCount = 0;
    _breach120HzCount = 0;
    _breach60HzCount = 0;
    _stressAngle = 0.0;
    _stressRadius = 20.0;
    _isStressTesting = true;

    // Run at ~60 Hz (16 ms) appending 1 point per tick
    _stressTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _stressPointCount++;
      _stressAngle += 0.08;
      _stressRadius = 20.0 + (_stressPointCount * 0.18);
      if (_stressRadius > 160.0) {
        _stressRadius = 20.0 + ((_stressPointCount % 800) * 0.18);
      }

      final x = _stressCenter.dx + _stressRadius * math.cos(_stressAngle);
      final y = _stressCenter.dy + _stressRadius * math.sin(_stressAngle * 0.7);

      _activePoints.add(StrokePoint(
        position: Offset(x, y),
        timestamp: Duration(milliseconds: _stressPointCount * 16),
        pressure: 0.5 + 0.4 * math.sin(_stressAngle),
        velocity: 300.0,
      ));

      _rebuildGeometry();

      // Stop after 2000 points automatically
      if (_stressPointCount >= 2000) {
        _stopStressTest();
      }
    });
  }

  void _stopStressTest() {
    _stressTimer?.cancel();
    _stressTimer = null;
    if (_isStressTesting) {
      setState(() {
        _isStressTesting = false;
      });
    }
  }

  // Freehand drawing handlers
  void _onPanStart(DragStartDetails details) {
    _stopStressTest();
    _activePoints = [
      StrokePoint(
        position: details.localPosition,
        timestamp: Duration.zero,
        pressure: 0.7,
      ),
    ];
    _rebuildGeometry();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _activePoints.add(
      StrokePoint(
        position: details.localPosition,
        timestamp: Duration(milliseconds: _activePoints.length * 8),
        pressure: 0.7,
      ),
    );
    _rebuildGeometry();
  }

  void _onPanEnd(DragEndDetails details) {
    _rebuildGeometry();
  }

  @override
  Widget build(BuildContext context) {
    final outline = _activeOutline;
    final hasOutline = outline != null && outline.isNotEmpty;

    // Check invariants
    bool noNan = true;
    if (hasOutline) {
      for (final p in outline.contour) {
        if (p.dx.isNaN || p.dy.isNaN || p.dx.isInfinite || p.dy.isInfinite) {
          noNan = false;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Stroke Geometry Debugger (v0.4.1)',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _outlineAlone ? Icons.visibility_off : Icons.visibility,
              color: _outlineAlone ? Colors.amber : Colors.white70,
            ),
            tooltip:
                _outlineAlone ? 'Show All Debug Layers' : 'View Outline Alone',
            onPressed: () {
              setState(() {
                _outlineAlone = !_outlineAlone;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Clear Stroke',
            onPressed: () {
              _stopStressTest();
              setState(() {
                _activePoints.clear();
                _activeOutline = null;
                _lastGenTimeMs = 0.0;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Preset Shapes Selector
          _buildPresetShapesBar(),

          // Interactive Canvas Area
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Container(
                    color: const Color(0xFF090D16),
                    width: double.infinity,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: _GeometryDebugCanvasPainter(
                        outline: _activeOutline,
                        activePoints: _activePoints,
                        outlineAlone: _outlineAlone,
                        showFill: _showFill,
                        showOutlineBorder: _showOutlineBorder,
                        showLeftBoundary: _showLeftBoundary,
                        showRightBoundary: _showRightBoundary,
                        showCenterline: _showCenterline,
                        showVertices: _showVertices,
                        showBounds: _showBounds,
                      ),
                    ),
                  ),
                ),

                // Live Floating Telemetry HUD
                Positioned(
                  top: 10,
                  left: 10,
                  child: _buildTelemetryHUD(hasOutline, noNan),
                ),

                // Live Stress Test Controller
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildStressTestCard(),
                ),
              ],
            ),
          ),

          // Layer Toggles & Configuration Drawer
          _buildControlsBottomBar(),
        ],
      ),
    );
  }

  Widget _buildPresetShapesBar() {
    final presets = [
      ('Single Dab', 'single_point_dab'),
      ('Short Stroke', 'short_stroke'),
      ('Horizontal', 'horizontal_line'),
      ('Vertical', 'vertical_line'),
      ('Diagonal', 'diagonal_line'),
      ('Smooth Curve', 'smooth_curve'),
      ('Circle', 'full_circle'),
      ('90° Corner', '90_deg_corner'),
      ('Acute Corner', 'acute_corner'),
      ('Obtuse Corner', 'obtuse_corner'),
      ('Zigzag', 'zigzag'),
      ('Rapid Direction', 'rapid_direction_changes'),
      ('Pressure Width', 'pressure_width_variation'),
      ('Duplicate Pts', 'duplicate_points'),
      ('Close Pts', 'extremely_close_points'),
      ('Zero Width', 'zero_width_stroke'),
    ];

    return Container(
      height: 44,
      color: const Color(0xFF1E293B),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final label = presets[i].$1;
          final key = presets[i].$2;
          final isSelected = _selectedShapeName == key && !_isStressTesting;

          return InkWell(
            onTap: () => _loadPresetShape(key),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTelemetryHUD(bool hasOutline, bool noNan) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xE60F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Centerline: ${_activePoints.length} pts',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Text(
                'Contour: ${_activeOutline?.contour.length ?? 0} vertices',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gen Time: ${_lastGenTimeMs.toStringAsFixed(2)} ms',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _lastGenTimeMs > 16.67
                      ? Colors.redAccent
                      : (_lastGenTimeMs > 8.33
                          ? Colors.orangeAccent
                          : Colors.greenAccent),
                ),
              ),
              const SizedBox(width: 8),
              if (_lastGenTimeMs > 8.33)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _lastGenTimeMs > 16.67 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    _lastGenTimeMs > 16.67 ? '> 60Hz' : '> 120Hz',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusBadge('No NaN', noNan),
              const SizedBox(width: 4),
              _buildStatusBadge('Closed', hasOutline),
              const SizedBox(width: 4),
              _buildStatusBadge(
                  'Bounds', hasOutline && _activeOutline!.bounds.isFinite),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF065F46) : const Color(0xFF991B1B),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: ${ok ? "✓" : "✗"}',
        style: const TextStyle(
            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStressTestCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xE61E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isStressTesting ? Colors.orangeAccent : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isStressTesting ? Colors.redAccent : Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                icon: Icon(_isStressTesting ? Icons.stop : Icons.play_arrow,
                    size: 14, color: Colors.white),
                label: Text(
                  _isStressTesting ? 'Stop Stress Test' : 'Live Stress Test',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                onPressed:
                    _isStressTesting ? _stopStressTest : _startStressTest,
              ),
            ],
          ),
          if (_isStressTesting || _breach120HzCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '> 8.3ms (120Hz): $_breach120HzCount',
              style: TextStyle(
                fontSize: 10,
                color: _breach120HzCount > 0
                    ? Colors.orangeAccent
                    : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '> 16.7ms (60Hz): $_breach60HzCount',
              style: TextStyle(
                fontSize: 10,
                color: _breach60HzCount > 0 ? Colors.redAccent : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsBottomBar() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Layer visibility toggles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToggleChip('Outline Alone', _outlineAlone,
                    (v) => setState(() => _outlineAlone = v)),
                _buildToggleChip(
                    'Fill', _showFill, (v) => setState(() => _showFill = v)),
                _buildToggleChip('Border', _showOutlineBorder,
                    (v) => setState(() => _showOutlineBorder = v)),
                _buildToggleChip('Left Boundary', _showLeftBoundary,
                    (v) => setState(() => _showLeftBoundary = v)),
                _buildToggleChip('Right Boundary', _showRightBoundary,
                    (v) => setState(() => _showRightBoundary = v)),
                _buildToggleChip('Centerline', _showCenterline,
                    (v) => setState(() => _showCenterline = v)),
                _buildToggleChip('Vertices', _showVertices,
                    (v) => setState(() => _showVertices = v)),
                _buildToggleChip('Bounds', _showBounds,
                    (v) => setState(() => _showBounds = v)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: Cap, Join, Width
          Row(
            children: [
              // Cap
              const Text('Cap: ',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
              DropdownButton<StrokeCapType>(
                value: _cap,
                dropdownColor: const Color(0xFF334155),
                style: const TextStyle(fontSize: 11, color: Colors.white),
                underline: const SizedBox(),
                items: StrokeCapType.values.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _cap = v);
                    _rebuildGeometry();
                  }
                },
              ),
              const SizedBox(width: 10),
              // Join
              const Text('Join: ',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
              DropdownButton<StrokeJoinType>(
                value: _join,
                dropdownColor: const Color(0xFF334155),
                style: const TextStyle(fontSize: 11, color: Colors.white),
                underline: const SizedBox(),
                items: StrokeJoinType.values.map((j) {
                  return DropdownMenuItem(value: j, child: Text(j.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _join = v);
                    _rebuildGeometry();
                  }
                },
              ),
              const SizedBox(width: 10),
              if (_join == StrokeJoinType.miter) ...[
                Text('Miter: ${_miterLimit.toStringAsFixed(1)}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white70)),
                SizedBox(
                  width: 80,
                  child: Slider(
                    value: _miterLimit,
                    min: 1.0,
                    max: 8.0,
                    divisions: 14,
                    onChanged: (v) {
                      setState(() => _miterLimit = v);
                      _rebuildGeometry();
                    },
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Dynamic width toggle
              _buildToggleChip('Dynamic (P+V)', _dynamicWidth, (v) {
                setState(() => _dynamicWidth = v);
                _rebuildGeometry();
              }),
              const Spacer(),
              // Width slider
              Text('W: ${_strokeWidth.toInt()}px',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: _strokeWidth,
                  min: 0.0,
                  max: 40.0,
                  divisions: 40,
                  onChanged: (v) {
                    setState(() => _strokeWidth = v);
                    _rebuildGeometry();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
                fontSize: 10, color: value ? Colors.black : Colors.white70)),
        selected: value,
        selectedColor: const Color(0xFF38BDF8),
        backgroundColor: const Color(0xFF334155),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: onChanged,
      ),
    );
  }
}

/// CustomPainter rendering all geometry debugger layers.
class _GeometryDebugCanvasPainter extends CustomPainter {
  final StrokeOutline? outline;
  final List<StrokePoint> activePoints;
  final bool outlineAlone;
  final bool showFill;
  final bool showOutlineBorder;
  final bool showLeftBoundary;
  final bool showRightBoundary;
  final bool showCenterline;
  final bool showVertices;
  final bool showBounds;

  _GeometryDebugCanvasPainter({
    required this.outline,
    required this.activePoints,
    required this.outlineAlone,
    required this.showFill,
    required this.showOutlineBorder,
    required this.showLeftBoundary,
    required this.showRightBoundary,
    required this.showCenterline,
    required this.showVertices,
    required this.showBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (outline == null || outline!.isEmpty) return;

    // Mode A: Final Outline Alone
    if (outlineAlone) {
      final fillPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(outline!.path, fillPaint);
      return;
    }

    // Mode B: Full Multi-layer Geometry Visual Debugger

    // 1. Fill Outline (translucent blue)
    if (showFill) {
      final fillPaint = Paint()
        ..color = const Color(0x3338BDF8)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(outline!.path, fillPaint);
    }

    // 2. Outline Border (solid light blue)
    if (showOutlineBorder) {
      final borderPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      canvas.drawPath(outline!.path, borderPaint);
    }

    // 3. Left Boundary (emerald green)
    if (showLeftBoundary && outline!.leftBoundary.isNotEmpty) {
      final leftPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true;
      _drawPolyline(canvas, outline!.leftBoundary, leftPaint);
    }

    // 4. Right Boundary (amber / orange)
    if (showRightBoundary && outline!.rightBoundary.isNotEmpty) {
      final rightPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true;
      _drawPolyline(canvas, outline!.rightBoundary, rightPaint);
    }

    // 5. Centerline (dashed/solid cyan)
    if (showCenterline && activePoints.isNotEmpty) {
      final centerPaint = Paint()
        ..color = const Color(0xFF06B6D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      _drawPolyline(
          canvas, activePoints.map((p) => p.position).toList(), centerPaint);
    }

    // 6. Control Points & Boundary Vertices
    if (showVertices) {
      final vertPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      for (final p in outline!.contour) {
        canvas.drawCircle(p, 2.0, vertPaint);
      }

      // Centerline input points (red circles)
      final centerDotPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.fill;
      for (final pt in activePoints) {
        canvas.drawCircle(pt.position, 2.5, centerDotPaint);
      }
    }

    // 7. Stroke Bounds (dashed yellow rectangle)
    if (showBounds && outline!.bounds.isFinite) {
      final boundsPaint = Paint()
        ..color = Colors.yellowAccent.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(outline!.bounds, boundsPaint);
    }
  }

  void _drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GeometryDebugCanvasPainter oldDelegate) => true;
}
