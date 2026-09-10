import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_paint/go_paint.dart';

void main() {
  group('v0.2: NoiseFilter Tests', () {
    test('Rejects displacement below threshold and accepts above threshold',
        () {
      final filter = NoiseFilter(minDistance: 2.0);
      const origin = Offset(100, 100);

      // Micro-displacement 0.8px (< 2.0px)
      const tinyMove = PointerSample(
        position: Offset(100.6, 100.5),
        timestamp: Duration.zero,
      );
      expect(filter.accept(tinyMove, origin), isFalse);

      // Clear displacement 3.0px (> 2.0px)
      const validMove = PointerSample(
        position: Offset(103.0, 100.0),
        timestamp: Duration.zero,
      );
      expect(filter.accept(validMove, origin), isTrue);
    });
  });

  group('v0.2: KinematicsTracker Tests', () {
    test('Resilient to irregular event intervals and pause gaps', () {
      final kinematics = KinematicsTracker(maxVelocity: 2000.0);

      const s0 =
          PointerSample(position: Offset(0, 0), timestamp: Duration.zero);
      const s1 = PointerSample(
          position: Offset(10, 0),
          timestamp: Duration(milliseconds: 10)); // 1000 px/s
      kinematics.update(s1, s0);
      expect(kinematics.smoothedVelocity, greaterThan(500.0));
      expect(kinematics.lastDirection.dx, closeTo(1.0, 0.01));

      // Irregular interval (25ms)
      const s2 = PointerSample(
          position: Offset(25, 0),
          timestamp: Duration(milliseconds: 35)); // 600 px/s
      kinematics.update(s2, s1);
      expect(kinematics.smoothedVelocity, inInclusiveRange(600.0, 1000.0));

      // Pause gap (> 150ms) should not produce erratic spikes
      const sPause = PointerSample(
          position: Offset(50, 0), timestamp: Duration(milliseconds: 300));
      kinematics.update(sPause, s2);
      expect(kinematics.smoothedVelocity.isFinite, isTrue);
    });
  });

  group('v0.2: PressureSource Tests', () {
    test('HardwarePressureSource applies gamma and clamps', () {
      const hw = HardwarePressureSource(pressureGamma: 0.8);
      const sample = PointerSample(
        position: Offset.zero,
        timestamp: Duration.zero,
        pressure: 0.5,
        deviceType: PointerDeviceKind.stylus,
      );
      final p = hw.resolve(sample);
      expect(p, closeTo(0.574, 0.02));
    });

    test('SimulatedPressureSource varies inversely with velocity', () {
      const sim = SimulatedPressureSource(minPressure: 0.2, maxPressure: 1.0);
      const sample = PointerSample(
        position: Offset.zero,
        timestamp: Duration.zero,
      );

      final slowP = sim.resolve(sample, velocity: 50.0, maxVelocity: 2000.0);
      final fastP = sim.resolve(sample, velocity: 1800.0, maxVelocity: 2000.0);

      expect(slowP, greaterThan(0.85),
          reason: 'Slow moves deposit higher pressure');
      expect(fastP, lessThan(0.45),
          reason: 'Fast moves deposit lower pressure');
      expect(slowP, greaterThan(fastP));
    });

    test(
        'AdaptivePressureSource delegates to hardware for stylus and simulated for touch',
        () {
      const adaptive = AdaptivePressureSource();

      const stylusSample = PointerSample(
        position: Offset.zero,
        timestamp: Duration.zero,
        pressure: 0.72,
        deviceType: PointerDeviceKind.stylus,
      );
      expect(adaptive.resolve(stylusSample), equals(0.72));

      const touchSample = PointerSample(
        position: Offset.zero,
        timestamp: Duration.zero,
        pressure: 1.0,
        deviceType: PointerDeviceKind.touch,
      );
      final touchP =
          adaptive.resolve(touchSample, velocity: 1500.0, maxVelocity: 2000.0);
      expect(touchP, lessThan(1.0), reason: 'Touch uses velocity simulation');
    });
  });

  group('v0.2: AdaptiveSmoother Tests', () {
    test('Dynamic velocity-dependent streamline calculation', () {
      const config = StabilizerConfig(
        velocityMin: 100.0,
        velocityMax: 1000.0,
        streamlineSlow: 0.50,
        streamlineFast: 0.05,
      );
      final smoother = AdaptiveSmoother(config: config);

      final factorSlow = smoother.computeStreamlineFactor(50.0);
      final factorMid = smoother.computeStreamlineFactor(550.0);
      final factorFast = smoother.computeStreamlineFactor(1200.0);

      expect(factorSlow, closeTo(0.50, 0.001));
      expect(factorMid, closeTo(0.275, 0.001));
      expect(factorFast, closeTo(0.05, 0.001));
    });
  });

  group('v0.2: CornerPreserver Tests', () {
    test(
        'Detects acute direction turns (> 65 deg) and returns reduced smoothing factor',
        () {
      const config =
          StabilizerConfig(cornerAngleDeg: 65.0, cornerSmoothingFactor: 0.12);
      final preserver = CornerPreserver(config: config);

      // Moving right along X-axis
      preserver.checkDirectionChange(const Offset(0, 100));
      preserver.checkDirectionChange(const Offset(50, 100));

      // Continuing straight along X-axis: no corner
      final straight = preserver.checkDirectionChange(const Offset(100, 100));
      expect(straight, isNull);

      // Sharp acute V-turn: reversing back left and down (120 deg turn)
      final acuteCorner = preserver.checkDirectionChange(const Offset(20, 150));
      expect(acuteCorner, isNotNull);
      expect(acuteCorner, equals(0.12));
    });
  });

  group('v0.2: Predictor Tests', () {
    test('Disabled by default and returns null', () {
      const config = StabilizerConfig(predictionEnabled: false);
      final predictor = Predictor(config: config);

      final tip = predictor.predictTip(
        position: const Offset(100, 100),
        direction: const Offset(1, 0),
        velocity: 500.0,
        width: 4.0,
        pressure: 1.0,
        timestamp: Duration.zero,
      );
      expect(tip, isNull);
    });

    test('When enabled, forward extrapolates capped at maxPredictionDistance',
        () {
      const config = StabilizerConfig(
        predictionEnabled: true,
        predictionHorizonMs: 16.0,
        maxPredictionDistance: 12.0,
      );
      final predictor = Predictor(config: config);

      // Moving fast: velocity 2000 px/s * 0.016s = 32px > 12px cap
      final tip = predictor.predictTip(
        position: const Offset(100, 100),
        direction: const Offset(1, 0),
        velocity: 2000.0,
        width: 4.0,
        pressure: 0.8,
        timestamp: Duration.zero,
      );

      expect(tip, isNotNull);
      expect(tip!.position.dx, closeTo(112.0, 0.01)); // Capped at +12px
      expect(tip.position.dy, equals(100.0));
      expect(tip.timestamp.inMilliseconds, equals(16));
    });
  });

  group('v0.2: MultiTouch State Machine & Policy Tests', () {
    test(
        'Second finger triggers multitouch state and completes stroke safely under default policy',
        () {
      final pointerInput = PointerInput(
        multiTouchPolicy: MultiTouchPolicy.completeCurrentStroke,
      );

      expect(pointerInput.state, equals(PointerInputState.idle));

      // 1. Primary finger down
      final stroke = pointerInput.onPointerDown(const PointerSample(
        position: Offset(50, 50),
        timestamp: Duration.zero,
        pointerId: 1,
      ));
      expect(stroke, isNotNull);
      expect(pointerInput.isDrawing, isTrue);
      expect(pointerInput.state, equals(PointerInputState.drawing));

      // 2. Primary finger moves
      pointerInput.onPointerMove(const PointerSample(
        position: Offset(70, 70),
        timestamp: Duration(milliseconds: 16),
        pointerId: 1,
      ));
      expect(pointerInput.activeStroke!.points.isNotEmpty, isTrue);

      // 3. Second finger touches down (pinch/zoom gesture begun)
      final completed = pointerInput.onPointerDown(const PointerSample(
        position: Offset(200, 200),
        timestamp: Duration(milliseconds: 25),
        pointerId: 2,
      ));

      // Under completeCurrentStroke policy, existing stroke is finalized and committed!
      expect(completed, isNotNull);
      expect(completed!.isComplete, isTrue);
      expect(pointerInput.state, equals(PointerInputState.multitouch));
      expect(pointerInput.isDrawing, isFalse);

      // Drawing move from finger 1 or 2 during multitouch is rejected
      final rejectedMove = pointerInput.onPointerMove(const PointerSample(
        position: Offset(80, 80),
        timestamp: Duration(milliseconds: 32),
        pointerId: 1,
      ));
      expect(rejectedMove, isNull);
    });

    test(
        'Predicted tip is transient: visible during active draw, absent on stroke completion',
        () {
      final stabilizer = Stabilizer(
        config: const StabilizerConfig(
          predictionEnabled: true,
          predictionHorizonMs: 16.0,
          maxPredictionDistance: 15.0,
        ),
      );
      final pointerInput = PointerInput(stabilizer: stabilizer);

      pointerInput.onPointerDown(const PointerSample(
        position: Offset(0, 0),
        timestamp: Duration.zero,
        pointerId: 1,
      ));

      pointerInput.onPointerMove(const PointerSample(
        position: Offset(50, 0),
        timestamp: Duration(milliseconds: 16),
        pointerId: 1,
      ));

      final active = pointerInput.onPointerMove(const PointerSample(
        position: Offset(100, 0),
        timestamp: Duration(milliseconds: 32),
        pointerId: 1,
      ));

      // Active stroke includes transient predicted tip
      expect(active, isNotNull);
      final realPointsBeforeUp = stabilizer.smoothedPoints.length;
      expect(active!.points.length, greaterThan(realPointsBeforeUp));

      // Up event completes stroke: must ONLY contain real smoothed points (predicted tip discarded)!
      final completed = pointerInput.onPointerUp(const PointerSample(
        position: Offset(120, 0),
        timestamp: Duration(milliseconds: 48),
        pointerId: 1,
      ));

      expect(completed, isNotNull);
      expect(completed!.points.length, equals(realPointsBeforeUp));
    });
  });
}
