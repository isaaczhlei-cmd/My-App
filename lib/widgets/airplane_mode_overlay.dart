import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/user_preferences_service.dart';

enum _AirplanePhase { takeoff, cruise, landing }

class AirplaneModeOverlay extends StatefulWidget {
  const AirplaneModeOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<AirplaneModeOverlay> createState() => _AirplaneModeOverlayState();
}

class _AirplaneModeOverlayState extends State<AirplaneModeOverlay>
    with TickerProviderStateMixin {
  static const _sweepDuration = Duration(seconds: 9);
  static const _turboDuration = Duration(milliseconds: 1800);
  static const _pauseDuration = Duration(seconds: 7);
  static const _planeWidth = 190.0;
  static const _planeHeight = 62.0;

  late final AnimationController _sweepController;
  late final AnimationController _rollController;
  late final Animation<double> _rollAnimation;
  Timer? _pauseTimer;
  bool _turboActive = false;
  bool _isDragging = false;
  Offset? _dragPosition;
  Offset? _lastDragPosition;
  DateTime? _lastDragAt;
  double _engineBurn = 0;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: _sweepDuration,
    )..addStatusListener(_handleSweepStatus);
    _rollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _rollAnimation = CurvedAnimation(
      parent: _rollController,
      curve: Curves.easeInOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSweep();
    });
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _sweepController
      ..removeStatusListener(_handleSweepStatus)
      ..dispose();
    _rollController.dispose();
    super.dispose();
  }

  void _handleSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _sweepController.duration = _sweepDuration;
    if (mounted) {
      setState(() {
        _turboActive = false;
        _engineBurn = 0;
      });
    }
    _pauseTimer?.cancel();
    _pauseTimer = Timer(_pauseDuration, () {
      if (mounted) _startSweep();
    });
  }

  void _startSweep({bool turbo = false}) {
    _pauseTimer?.cancel();
    _sweepController.duration = turbo ? _turboDuration : _sweepDuration;
    _sweepController.forward(from: 0);
  }

  void _activateTurbo() {
    setState(() {
      _turboActive = true;
      _engineBurn = 0.9;
    });
    _pauseTimer?.cancel();
    _sweepController.duration = _turboDuration;
    _sweepController.forward(
      from: _sweepController.isAnimating ? _sweepController.value : 0,
    );
  }

  void _triggerRoll() {
    _rollController.forward(from: 0);
  }

  void _startDrag(Offset position) {
    _pauseTimer?.cancel();
    _sweepController.stop();
    setState(() {
      _isDragging = true;
      _turboActive = false;
      _dragPosition = position;
      _lastDragPosition = position;
      _lastDragAt = DateTime.now();
      _engineBurn = 0.34;
    });
  }

  void _updateDrag(DragUpdateDetails details, BoxConstraints constraints) {
    final raw = (_dragPosition ?? Offset.zero) + details.delta;
    final next = Offset(
      raw.dx.clamp(0, max(0, constraints.maxWidth - _planeWidth)).toDouble(),
      raw.dy.clamp(0, max(0, constraints.maxHeight - _planeHeight)).toDouble(),
    );
    final now = DateTime.now();
    final previous = _lastDragPosition ?? next;
    final elapsedMs = max(1, now.difference(_lastDragAt ?? now).inMilliseconds);
    final velocity = (next - previous).distance / elapsedMs * 1000;

    setState(() {
      _dragPosition = next;
      _lastDragPosition = next;
      _lastDragAt = now;
      _engineBurn = (0.22 + velocity / 1800).clamp(0.22, 1.0).toDouble();
    });
  }

  void _endDrag() {
    setState(() {
      _isDragging = false;
      _lastDragPosition = null;
      _lastDragAt = null;
      _engineBurn = 0.16;
    });
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _dragPosition = null;
        _engineBurn = 0;
      });
      _startSweep();
    });
  }

  _AirplanePhase _phaseFor({
    required double progress,
    required Offset position,
    required BoxConstraints constraints,
  }) {
    if (_isDragging) {
      if (position.dy > constraints.maxHeight * 0.62) {
        return _AirplanePhase.landing;
      }
      if (_engineBurn > 0.55) return _AirplanePhase.takeoff;
      return _AirplanePhase.cruise;
    }
    if (progress < 0.18) return _AirplanePhase.takeoff;
    if (progress > 0.82) return _AirplanePhase.landing;
    return _AirplanePhase.cruise;
  }

  double _pitchFor(_AirplanePhase phase) {
    return switch (phase) {
      _AirplanePhase.takeoff => -0.075,
      _AirplanePhase.landing => 0.055,
      _AirplanePhase.cruise => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: UserPreferencesService.instance,
            builder: (context, _) {
              final prefs = UserPreferencesService.instance;
              if (!prefs.tinyFlightAnimationEnabled) {
                return const SizedBox.shrink();
              }

              return IgnorePointer(
                ignoring: false,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: Listenable.merge([
                          _sweepController,
                          _rollController,
                        ]),
                        builder: (context, _) {
                          final progress = _sweepController.value;
                          final x =
                              -_planeWidth +
                              (constraints.maxWidth + _planeWidth * 2) *
                                  progress;
                          final cruiseY =
                              constraints.maxHeight * 0.10 +
                              sin(progress * pi * 2) * 12;
                          final y = cruiseY.clamp(
                            0,
                            max(0, constraints.maxHeight - _planeHeight),
                          );
                          final position =
                              _dragPosition ?? Offset(x, y.toDouble());
                          final phase = _phaseFor(
                            progress: progress,
                            position: position,
                            constraints: constraints,
                          );
                          final opacity = _isDragging || _turboActive
                              ? 0.96
                              : 0.78;
                          final burn = max(
                            _engineBurn,
                            _turboActive ? 0.9 : 0,
                          ).toDouble();

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: position.dx,
                                top: position.dy,
                                width: _planeWidth,
                                height: _planeHeight,
                                child: Semantics(
                                  button: true,
                                  label: 'Boeing 777-9 airplane mode',
                                  hint:
                                      'Tap for faster flight, double tap for a roll, or drag the plane',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: _activateTurbo,
                                    onDoubleTap: _triggerRoll,
                                    onPanStart: (_) => _startDrag(position),
                                    onPanUpdate: (details) =>
                                        _updateDrag(details, constraints),
                                    onPanEnd: (_) => _endDrag(),
                                    onPanCancel: _endDrag,
                                    child: RotationTransition(
                                      turns: _rollAnimation,
                                      child: Transform.rotate(
                                        angle: _pitchFor(phase),
                                        child: Opacity(
                                          opacity: opacity,
                                          child: CustomPaint(
                                            painter: _Boeing777XPlanePainter(
                                              airlineName:
                                                  prefs.airplaneModeAirlineName,
                                              phase: phase,
                                              engineBurn: burn,
                                              accentColor: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fuselageColor: Colors.white,
                                              trailColor: Colors.white
                                                  .withValues(
                                                    alpha:
                                                        _isDragging ||
                                                            _turboActive
                                                        ? 0.28
                                                        : 0.14,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Boeing777XPlanePainter extends CustomPainter {
  const _Boeing777XPlanePainter({
    required this.airlineName,
    required this.phase,
    required this.engineBurn,
    required this.accentColor,
    required this.fuselageColor,
    required this.trailColor,
  });

  final String airlineName;
  final _AirplanePhase phase;
  final double engineBurn;
  final Color accentColor;
  final Color fuselageColor;
  final Color trailColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * 0.5;
    final bodyPaint = Paint()
      ..color = fuselageColor.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = const Color(0xFF0A2733).withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;
    final glassPaint = Paint()
      ..color = const Color(0xFF163E63).withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    final trailPaint = Paint()
      ..color = trailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (final offset in [-15.0, 0.0, 15.0]) {
      canvas.drawLine(
        Offset(0, cy + offset),
        Offset(size.width * 0.18, cy + offset * 0.42),
        trailPaint,
      );
    }

    _drawEngineFlames(canvas, size, cy);

    final upperWing = Path()
      ..moveTo(size.width * 0.42, cy - 3)
      ..lineTo(size.width * 0.15, size.height * 0.02)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.04,
        size.width * 0.62,
        cy - 3,
        size.width * 0.74,
        cy - 1,
      )
      ..close();
    final lowerWing = Path()
      ..moveTo(size.width * 0.43, cy + 3)
      ..lineTo(size.width * 0.15, size.height * 0.98)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.96,
        size.width * 0.62,
        cy + 3,
        size.width * 0.74,
        cy + 1,
      )
      ..close();
    canvas.drawPath(upperWing, bodyPaint);
    canvas.drawPath(lowerWing, bodyPaint);
    canvas.drawPath(upperWing, outlinePaint);
    canvas.drawPath(lowerWing, outlinePaint);

    _drawEngine(canvas, Offset(size.width * 0.38, cy - 13), true);
    _drawEngine(canvas, Offset(size.width * 0.38, cy + 13), false);

    final fuselage = RRect.fromLTRBR(
      size.width * 0.16,
      cy - 9,
      size.width * 0.90,
      cy + 9,
      const Radius.circular(18),
    );
    canvas.drawRRect(fuselage, bodyPaint);
    canvas.drawRRect(fuselage, outlinePaint);

    final nose = Path()
      ..moveTo(size.width * 0.86, cy - 9)
      ..cubicTo(
        size.width * 0.98,
        cy - 7,
        size.width * 1.02,
        cy,
        size.width * 0.86,
        cy + 9,
      )
      ..close();
    canvas.drawPath(nose, bodyPaint);
    canvas.drawPath(nose, outlinePaint);

    final cockpit = Path()
      ..moveTo(size.width * 0.84, cy - 6)
      ..lineTo(size.width * 0.93, cy - 3)
      ..lineTo(size.width * 0.86, cy + 1)
      ..close();
    canvas.drawPath(cockpit, glassPaint);

    final stripe = RRect.fromLTRBR(
      size.width * 0.25,
      cy - 3,
      size.width * 0.78,
      cy + 3,
      const Radius.circular(4),
    );
    canvas.drawRRect(stripe, accentPaint);

    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.37 + i * 0.045), cy - 5.6),
        1.25,
        glassPaint,
      );
    }

    _paintAirlineName(canvas, size, cy);
    _drawTail(canvas, size, cy, bodyPaint, accentPaint, outlinePaint);
    _drawFlapsAndGear(canvas, size, cy);
  }

  void _paintAirlineName(Canvas canvas, Size size, double cy) {
    final label = airlineName.trim().isEmpty ? 'flightprint Air' : airlineName;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF06242F).withValues(alpha: 0.92),
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: size.width * 0.32);
    textPainter.paint(
      canvas,
      Offset(size.width * 0.48, cy - textPainter.height / 2),
    );
  }

  void _drawTail(
    Canvas canvas,
    Size size,
    double cy,
    Paint bodyPaint,
    Paint accentPaint,
    Paint outlinePaint,
  ) {
    final verticalTail = Path()
      ..moveTo(size.width * 0.18, cy - 7)
      ..lineTo(size.width * 0.07, cy - 28)
      ..quadraticBezierTo(size.width * 0.14, cy - 19, size.width * 0.23, cy - 6)
      ..close();
    final upperStab = Path()
      ..moveTo(size.width * 0.18, cy - 4)
      ..lineTo(size.width * 0.06, cy - 16)
      ..lineTo(size.width * 0.22, cy - 2)
      ..close();
    final lowerStab = Path()
      ..moveTo(size.width * 0.18, cy + 4)
      ..lineTo(size.width * 0.06, cy + 16)
      ..lineTo(size.width * 0.22, cy + 2)
      ..close();
    canvas.drawPath(verticalTail, accentPaint);
    canvas.drawPath(upperStab, bodyPaint);
    canvas.drawPath(lowerStab, bodyPaint);
    canvas.drawPath(verticalTail, outlinePaint);
    canvas.drawPath(upperStab, outlinePaint);
    canvas.drawPath(lowerStab, outlinePaint);
  }

  void _drawEngine(Canvas canvas, Offset center, bool upper) {
    final enginePaint = Paint()
      ..color = const Color(0xFFE8F3F7)
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = const Color(0xFF0A2733).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fanPaint = Paint()
      ..color = const Color(0xFF163E63).withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCenter(center: center, width: 17, height: 9);
    canvas.drawOval(rect, enginePaint);
    canvas.drawOval(rect, rimPaint);
    canvas.drawCircle(center.translate(2, 0), 2.2, fanPaint);
  }

  void _drawFlapsAndGear(Canvas canvas, Size size, double cy) {
    final flapExtension = switch (phase) {
      _AirplanePhase.takeoff => 0.45,
      _AirplanePhase.landing => 0.85,
      _AirplanePhase.cruise => 0.0,
    };
    final gearExtension = switch (phase) {
      _AirplanePhase.takeoff => 0.25,
      _AirplanePhase.landing => 1.0,
      _AirplanePhase.cruise => 0.0,
    };
    if (flapExtension > 0) {
      final flapPaint = Paint()
        ..color = const Color(0xFFE8F3F7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.32, cy - 15),
        Offset(size.width * (0.43 + flapExtension * 0.04), cy - 17),
        flapPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.32, cy + 15),
        Offset(size.width * (0.43 + flapExtension * 0.04), cy + 17),
        flapPaint,
      );
    }
    if (gearExtension > 0) {
      final gearPaint = Paint()
        ..color = const Color(0xFF0A2733).withValues(alpha: 0.74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final wheelPaint = Paint()
        ..color = const Color(0xFF0A2733).withValues(alpha: 0.74)
        ..style = PaintingStyle.fill;
      final drop = 7 * gearExtension;
      for (final x in [size.width * 0.46, size.width * 0.70]) {
        canvas.drawLine(Offset(x, cy + 8), Offset(x, cy + 8 + drop), gearPaint);
        canvas.drawCircle(Offset(x, cy + 10 + drop), 2.1, wheelPaint);
      }
    }
  }

  void _drawEngineFlames(Canvas canvas, Size size, double cy) {
    if (engineBurn <= 0) return;
    final burn = engineBurn.clamp(0.0, 1.0);
    final flamePaint = Paint()..style = PaintingStyle.fill;
    for (final offset in [-13.0, 13.0]) {
      final base = Offset(size.width * 0.29, cy + offset);
      final flame = Path()
        ..moveTo(base.dx, base.dy - 4)
        ..quadraticBezierTo(
          base.dx - 18 - burn * 26,
          base.dy,
          base.dx,
          base.dy + 4,
        )
        ..close();
      flamePaint.color = Color.lerp(
        const Color(0xFFFFE082),
        const Color(0xFFFF4D1D),
        burn,
      )!.withValues(alpha: 0.78);
      canvas.drawPath(flame, flamePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Boeing777XPlanePainter oldDelegate) {
    return airlineName != oldDelegate.airlineName ||
        phase != oldDelegate.phase ||
        engineBurn != oldDelegate.engineBurn ||
        accentColor != oldDelegate.accentColor ||
        fuselageColor != oldDelegate.fuselageColor ||
        trailColor != oldDelegate.trailColor;
  }
}
