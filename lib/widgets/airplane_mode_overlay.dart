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
  static const _planeWidth = 250.0;
  static const _planeHeight = 82.0;

  late final AnimationController _sweepController;
  late final AnimationController _rollController;
  late final Animation<double> _rollAnimation;
  final Random _routeRandom = Random();
  bool _turboActive = false;
  bool _isDragging = false;
  bool _facingRight = true;
  Offset? _dragPosition;
  Offset? _lastDragPosition;
  double _lastDragVelocityDx = 0;
  DateTime? _lastDragAt;
  double _engineBurn = 0;
  double _leftRouteFactor = 0.12;
  double _rightRouteFactor = 0.28;
  double _routeWavePhase = 0;
  double _routeWaveAmplitude = 12;

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
    _sweepController
      ..removeStatusListener(_handleSweepStatus)
      ..dispose();
    _rollController.dispose();
    super.dispose();
  }

  void _handleSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    if (_isDragging) return;
    _sweepController.duration = _sweepDuration;
    if (mounted) {
      setState(() {
        _turboActive = false;
        _facingRight = status == AnimationStatus.dismissed;
        _chooseNextRoute(status);
        _engineBurn = 0;
      });
    }
    _animateTowardEdge(_facingRight);
  }

  double _randomRouteFactor() {
    return 0.08 + _routeRandom.nextDouble() * 0.46;
  }

  void _chooseNextRoute(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _leftRouteFactor = _randomRouteFactor();
    } else if (status == AnimationStatus.dismissed) {
      _rightRouteFactor = _randomRouteFactor();
    }
    _routeWavePhase = _routeRandom.nextDouble() * pi * 2;
    _routeWaveAmplitude = 6 + _routeRandom.nextDouble() * 16;
  }

  void _startSweep({bool turbo = false}) {
    _animateTowardEdge(_facingRight, turbo: turbo);
  }

  void _animateTowardEdge(bool movingRight, {bool turbo = false}) {
    final baseDuration = turbo ? _turboDuration : _sweepDuration;
    final remaining = movingRight
        ? (1 - _sweepController.value).clamp(0.0, 1.0)
        : _sweepController.value.clamp(0.0, 1.0);
    final duration = baseDuration * max(0.18, remaining);
    _sweepController.duration = duration;
    if (movingRight) {
      _sweepController.forward();
    } else {
      _sweepController.reverse();
    }
  }

  void _activateTurbo() {
    setState(() {
      _turboActive = true;
      _engineBurn = 0.9;
    });
    _startSweep(turbo: true);
  }

  void _triggerRoll() {
    _rollController.forward(from: 0);
  }

  void _startDrag(Offset position) {
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
    final velocityDx = (next.dx - previous.dx) / elapsedMs * 1000;

    setState(() {
      _dragPosition = next;
      _lastDragPosition = next;
      _lastDragVelocityDx = velocityDx;
      _lastDragAt = now;
      _engineBurn = (0.22 + velocity / 1800).clamp(0.22, 1.0).toDouble();
    });
  }

  void _endDrag([BoxConstraints? constraints]) {
    final droppedPosition = _dragPosition;
    if (droppedPosition != null && constraints != null) {
      _launchFromDrop(droppedPosition, constraints);
    }
    setState(() {
      _isDragging = false;
      _dragPosition = null;
      _lastDragPosition = null;
      _lastDragAt = null;
      _engineBurn = 0.72;
    });
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _lastDragVelocityDx = 0;
        _engineBurn = 0;
      });
    });
  }

  void _launchFromDrop(Offset position, BoxConstraints constraints) {
    final visibleTravel = max(1, constraints.maxWidth - _planeWidth).toDouble();
    final progress = (position.dx / visibleTravel).clamp(0.0, 1.0).toDouble();
    final routeFactor = (position.dy / max(1, constraints.maxHeight))
        .clamp(0.08, 0.54)
        .toDouble();
    final movingRight = _lastDragVelocityDx.abs() < 45
        ? _facingRight
        : _lastDragVelocityDx >= 0;

    _sweepController.value = progress;
    _facingRight = movingRight;
    if (movingRight) {
      _leftRouteFactor = routeFactor;
      _rightRouteFactor = _randomRouteFactor();
    } else {
      _rightRouteFactor = routeFactor;
      _leftRouteFactor = _randomRouteFactor();
    }
    _routeWavePhase = _routeRandom.nextDouble() * pi * 2;
    _routeWaveAmplitude = 10 + _routeRandom.nextDouble() * 18;
    _animateTowardEdge(movingRight, turbo: true);
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
                          final visibleTravel = max(
                            0,
                            constraints.maxWidth - _planeWidth,
                          ).toDouble();
                          final x = visibleTravel * progress;
                          final leftY =
                              constraints.maxHeight * _leftRouteFactor;
                          final rightY =
                              constraints.maxHeight * _rightRouteFactor;
                          final routeY = leftY + (rightY - leftY) * progress;
                          final cruiseY =
                              routeY +
                              sin(progress * pi * 2 + _routeWavePhase) *
                                  _routeWaveAmplitude;
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
                              ? 1.0
                              : 0.92;
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
                                    onPanEnd: (_) => _endDrag(constraints),
                                    onPanCancel: () => _endDrag(constraints),
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
                                              airlineCode:
                                                  prefs.airplaneModeAirlineCode,
                                              facingRight: _facingRight,
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
    required this.airlineCode,
    required this.facingRight,
    required this.phase,
    required this.engineBurn,
    required this.accentColor,
    required this.fuselageColor,
    required this.trailColor,
  });

  final String airlineName;
  final String airlineCode;
  final bool facingRight;
  final _AirplanePhase phase;
  final double engineBurn;
  final Color accentColor;
  final Color fuselageColor;
  final Color trailColor;

  @override
  void paint(Canvas canvas, Size size) {
    final brand = _AirlineBrand.forCode(airlineCode, accentColor);
    final cy = size.height * 0.5;
    final shadowPaint = Paint()
      ..color = const Color(0xFF001317).withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final fuselagePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fuselageColor,
          const Color(0xFFE7EEF1),
          const Color(0xFFBBC8CF),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(Rect.fromLTWH(0, cy - 15, size.width, 30))
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = const Color(0xFF0A2733).withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;
    final primaryPaint = Paint()
      ..color = brand.primary.withValues(alpha: 0.97)
      ..style = PaintingStyle.fill;
    final secondaryPaint = Paint()
      ..color = brand.secondary.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final glassPaint = Paint()
      ..color = const Color(0xFF092C42).withValues(alpha: 0.86)
      ..style = PaintingStyle.fill;
    final trailPaint = Paint()
      ..color = trailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.save();
    if (!facingRight) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    for (final offset in [-11.0, 0.0, 11.0]) {
      canvas.drawLine(
        Offset(size.width * 0.01, cy + offset),
        Offset(size.width * 0.13, cy + offset * 0.36),
        trailPaint,
      );
    }

    _drawEngineFlames(canvas, size, cy);

    final fuselage = Path()
      ..moveTo(size.width * 0.13, cy - 12)
      ..cubicTo(
        size.width * 0.34,
        cy - 18,
        size.width * 0.79,
        cy - 17,
        size.width * 0.91,
        cy - 11,
      )
      ..cubicTo(
        size.width * 0.99,
        cy - 6,
        size.width * 1.00,
        cy,
        size.width * 0.91,
        cy + 11,
      )
      ..cubicTo(
        size.width * 0.73,
        cy + 18,
        size.width * 0.31,
        cy + 16,
        size.width * 0.13,
        cy + 11,
      )
      ..cubicTo(
        size.width * 0.08,
        cy + 8,
        size.width * 0.08,
        cy - 8,
        size.width * 0.13,
        cy - 12,
      )
      ..close();
    canvas.drawPath(fuselage.shift(const Offset(0, 2.5)), shadowPaint);

    _drawTail(canvas, size, cy, primaryPaint, secondaryPaint, outlinePaint);
    _drawWing(canvas, size, cy, primaryPaint, secondaryPaint, outlinePaint);
    _drawEngine(canvas, size, cy, primaryPaint, outlinePaint);

    canvas.drawPath(fuselage, fuselagePaint);
    canvas.drawPath(fuselage, outlinePaint);

    final bellyStripe = Path()
      ..moveTo(size.width * 0.16, cy + 5)
      ..cubicTo(
        size.width * 0.38,
        cy + 11,
        size.width * 0.72,
        cy + 12,
        size.width * 0.90,
        cy + 7,
      )
      ..lineTo(size.width * 0.90, cy + 12)
      ..cubicTo(
        size.width * 0.70,
        cy + 17,
        size.width * 0.33,
        cy + 15,
        size.width * 0.15,
        cy + 10,
      )
      ..close();
    canvas.drawPath(bellyStripe, primaryPaint);

    final thinStripe = Path()
      ..moveTo(size.width * 0.18, cy + 2)
      ..cubicTo(
        size.width * 0.40,
        cy + 5,
        size.width * 0.72,
        cy + 6,
        size.width * 0.88,
        cy + 3,
      );
    canvas.drawPath(
      thinStripe,
      Paint()
        ..color = brand.secondary.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    final panelPaint = Paint()
      ..color = const Color(0xFF35515A).withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final x in [0.20, 0.39, 0.56, 0.74, 0.86]) {
      canvas.drawLine(
        Offset(size.width * x, cy - 11),
        Offset(size.width * x, cy + 11),
        panelPaint,
      );
    }

    _drawCockpit(canvas, size, cy, glassPaint);
    _drawDoorsAndWindows(canvas, size, cy, glassPaint, outlinePaint);
    _drawFlapsAndGear(canvas, size, cy);
    canvas.restore();

    _paintAirlineName(canvas, size, cy, brand);
    _drawBrandMark(canvas, size, cy, brand);
  }

  void _paintAirlineName(
    Canvas canvas,
    Size size,
    double cy,
    _AirlineBrand brand,
  ) {
    final label = airlineName.trim().isEmpty ? brand.name : airlineName.trim();
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: brand.textColor,
          fontSize: 9.2,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: size.width * 0.30);
    textPainter.paint(
      canvas,
      Offset(
        facingRight ? size.width * 0.44 : size.width * 0.26 - textPainter.width,
        cy - 8 - textPainter.height / 2,
      ),
    );
  }

  void _drawTail(
    Canvas canvas,
    Size size,
    double cy,
    Paint primaryPaint,
    Paint secondaryPaint,
    Paint outlinePaint,
  ) {
    final verticalTail = Path()
      ..moveTo(size.width * 0.13, cy - 10)
      ..lineTo(size.width * 0.06, cy - 33)
      ..quadraticBezierTo(size.width * 0.13, cy - 30, size.width * 0.21, cy - 8)
      ..close();
    final horizontalStab = Path()
      ..moveTo(size.width * 0.14, cy - 2)
      ..lineTo(size.width * 0.03, cy - 13)
      ..lineTo(size.width * 0.20, cy)
      ..close();
    canvas.drawPath(verticalTail, primaryPaint);
    canvas.drawPath(horizontalStab, secondaryPaint);
    canvas.drawPath(verticalTail, outlinePaint);
    canvas.drawPath(horizontalStab, outlinePaint);
  }

  void _drawWing(
    Canvas canvas,
    Size size,
    double cy,
    Paint primaryPaint,
    Paint secondaryPaint,
    Paint outlinePaint,
  ) {
    final wing = Path()
      ..moveTo(size.width * 0.46, cy + 3)
      ..lineTo(size.width * 0.25, cy + 33)
      ..quadraticBezierTo(size.width * 0.41, cy + 26, size.width * 0.63, cy + 7)
      ..lineTo(size.width * 0.56, cy + 3)
      ..close();
    final foldedTip = Path()
      ..moveTo(size.width * 0.25, cy + 33)
      ..lineTo(size.width * 0.20, cy + 25)
      ..lineTo(size.width * 0.30, cy + 31)
      ..close();
    canvas.drawPath(wing, secondaryPaint);
    canvas.drawPath(foldedTip, primaryPaint);
    canvas.drawPath(wing, outlinePaint);
    canvas.drawPath(foldedTip, outlinePaint);
    final hingePaint = Paint()
      ..color = const Color(0xFF0A2733).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width * 0.28, cy + 31),
      Offset(size.width * 0.24, cy + 26),
      hingePaint,
    );
    for (final x in [0.39, 0.46, 0.53]) {
      canvas.drawLine(
        Offset(size.width * x, cy + 8),
        Offset(size.width * (x - 0.07), cy + 23),
        hingePaint,
      );
    }
  }

  void _drawEngine(
    Canvas canvas,
    Size size,
    double cy,
    Paint primaryPaint,
    Paint outlinePaint,
  ) {
    final center = Offset(size.width * 0.43, cy + 19);
    final enginePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8FBFC), Color(0xFFBBC7CD)],
      ).createShader(Rect.fromCenter(center: center, width: 46, height: 25))
      ..style = PaintingStyle.fill;
    final fanPaint = Paint()
      ..color = const Color(0xFF163E63).withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCenter(center: center, width: 46, height: 25);
    canvas.drawOval(rect, enginePaint);
    canvas.drawOval(rect, outlinePaint);
    final intakePaint = Paint()
      ..color = const Color(0xFF163E63).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawOval(rect.deflate(4), intakePaint);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(10, 0), width: 15, height: 15),
      fanPaint,
    );
    final bladePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      canvas.drawLine(
        center.translate(10, 0),
        center.translate(10 + cos(angle) * 7, sin(angle) * 7),
        bladePaint,
      );
    }
    canvas.drawArc(rect.deflate(3), 1.0, 1.7, false, primaryPaint);
  }

  void _drawCockpit(Canvas canvas, Size size, double cy, Paint glassPaint) {
    final cockpit = Path()
      ..moveTo(size.width * 0.86, cy - 9)
      ..lineTo(size.width * 0.94, cy - 6)
      ..quadraticBezierTo(size.width * 0.91, cy - 2, size.width * 0.84, cy - 3)
      ..close();
    canvas.drawPath(cockpit, glassPaint);
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawLine(
      Offset(size.width * 0.885, cy - 8),
      Offset(size.width * 0.885, cy - 2.5),
      framePaint,
    );
  }

  void _drawDoorsAndWindows(
    Canvas canvas,
    Size size,
    double cy,
    Paint glassPaint,
    Paint outlinePaint,
  ) {
    final doorPaint = Paint()
      ..color = const Color(0xFF102F3C).withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final x in [0.22, 0.39, 0.70, 0.82]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * x, cy - 10, 5, 10),
          const Radius.circular(1.5),
        ),
        doorPaint,
      );
    }
    for (var i = 0; i < 34; i++) {
      final gap = i > 10 && i < 14 ? 0.011 : 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * (0.25 + i * 0.016 + gap), cy - 7.7),
            width: 2.6,
            height: 2.2,
          ),
          const Radius.circular(1),
        ),
        glassPaint,
      );
    }
  }

  void _drawBrandMark(
    Canvas canvas,
    Size size,
    double cy,
    _AirlineBrand brand,
  ) {
    final code = airlineCode.trim().isEmpty
        ? brand.code
        : airlineCode.trim().toUpperCase();
    final label = code.length > 3 ? code.substring(0, 3) : code;
    final badge = Rect.fromCircle(
      center: Offset(
        facingRight ? size.width * 0.115 : size.width * 0.885,
        cy - 18,
      ),
      radius: 9,
    );
    canvas.drawOval(
      badge,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: brand.primary,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 20);
    textPainter.paint(
      canvas,
      Offset(
        badge.center.dx - textPainter.width / 2,
        badge.center.dy - textPainter.height / 2,
      ),
    );
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
        Offset(size.width * 0.35, cy + 25),
        Offset(size.width * (0.48 + flapExtension * 0.03), cy + 18),
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
      final drop = 9 * gearExtension;
      final noseX = size.width * 0.86;
      canvas.drawLine(
        Offset(noseX, cy + 10),
        Offset(noseX, cy + 10 + drop),
        gearPaint,
      );
      canvas.drawCircle(Offset(noseX, cy + 13 + drop), 2.0, wheelPaint);
      for (final x in [size.width * 0.52, size.width * 0.59]) {
        canvas.drawLine(
          Offset(x, cy + 11),
          Offset(x, cy + 11 + drop),
          gearPaint,
        );
        for (final wheelX in [-4.5, -1.5, 1.5, 4.5]) {
          canvas.drawCircle(
            Offset(x + wheelX, cy + 14 + drop),
            1.8,
            wheelPaint,
          );
        }
      }
    }
  }

  void _drawEngineFlames(Canvas canvas, Size size, double cy) {
    if (engineBurn <= 0) return;
    final burn = engineBurn.clamp(0.0, 1.0);
    final flamePaint = Paint()..style = PaintingStyle.fill;
    final base = Offset(size.width * 0.36, cy + 18);
    final flame = Path()
      ..moveTo(base.dx, base.dy - 5)
      ..quadraticBezierTo(
        base.dx - 20 - burn * 28,
        base.dy,
        base.dx,
        base.dy + 5,
      )
      ..close();
    flamePaint.color = Color.lerp(
      const Color(0xFFFFE082),
      const Color(0xFFFF4D1D),
      burn,
    )!.withValues(alpha: 0.78);
    canvas.drawPath(flame, flamePaint);
  }

  @override
  bool shouldRepaint(covariant _Boeing777XPlanePainter oldDelegate) {
    return airlineName != oldDelegate.airlineName ||
        airlineCode != oldDelegate.airlineCode ||
        phase != oldDelegate.phase ||
        engineBurn != oldDelegate.engineBurn ||
        accentColor != oldDelegate.accentColor ||
        fuselageColor != oldDelegate.fuselageColor ||
        trailColor != oldDelegate.trailColor;
  }
}

class _AirlineBrand {
  const _AirlineBrand({
    required this.name,
    required this.code,
    required this.primary,
    required this.secondary,
    required this.textColor,
  });

  final String name;
  final String code;
  final Color primary;
  final Color secondary;
  final Color textColor;

  static _AirlineBrand forCode(String rawCode, Color fallback) {
    final code = rawCode.trim().toUpperCase();
    final overrides = <String, _AirlineBrand>{
      'AA': _AirlineBrand(
        name: 'American Airlines',
        code: 'AA',
        primary: Color(0xFF1F4E79),
        secondary: Color(0xFFC9002B),
        textColor: Color(0xFF17324D),
      ),
      'AC': _AirlineBrand(
        name: 'Air Canada',
        code: 'AC',
        primary: Color(0xFF101820),
        secondary: Color(0xFFE31B23),
        textColor: Color(0xFF101820),
      ),
      'AF': _AirlineBrand(
        name: 'Air France',
        code: 'AF',
        primary: Color(0xFF002157),
        secondary: Color(0xFFE31B23),
        textColor: Color(0xFF002157),
      ),
      'AS': _AirlineBrand(
        name: 'Alaska Airlines',
        code: 'AS',
        primary: Color(0xFF004B7A),
        secondary: Color(0xFF69BE28),
        textColor: Color(0xFF004B7A),
      ),
      'BA': _AirlineBrand(
        name: 'British Airways',
        code: 'BA',
        primary: Color(0xFF075AAA),
        secondary: Color(0xFFC8102E),
        textColor: Color(0xFF075AAA),
      ),
      'B6': _AirlineBrand(
        name: 'JetBlue',
        code: 'B6',
        primary: Color(0xFF00205B),
        secondary: Color(0xFF00A3E0),
        textColor: Color(0xFF00205B),
      ),
      'CX': _AirlineBrand(
        name: 'Cathay Pacific',
        code: 'CX',
        primary: Color(0xFF006564),
        secondary: Color(0xFFA7A8AA),
        textColor: Color(0xFF006564),
      ),
      'DL': _AirlineBrand(
        name: 'Delta Air Lines',
        code: 'DL',
        primary: Color(0xFF862633),
        secondary: Color(0xFF003A70),
        textColor: Color(0xFF003A70),
      ),
      'EK': _AirlineBrand(
        name: 'Emirates',
        code: 'EK',
        primary: Color(0xFFD71920),
        secondary: Color(0xFF007A3D),
        textColor: Color(0xFFD71920),
      ),
      'LH': _AirlineBrand(
        name: 'Lufthansa',
        code: 'LH',
        primary: Color(0xFF05164D),
        secondary: Color(0xFFFFCC00),
        textColor: Color(0xFF05164D),
      ),
      'QR': _AirlineBrand(
        name: 'Qatar Airways',
        code: 'QR',
        primary: Color(0xFF5C0632),
        secondary: Color(0xFF8A1538),
        textColor: Color(0xFF5C0632),
      ),
      'SQ': _AirlineBrand(
        name: 'Singapore Airlines',
        code: 'SQ',
        primary: Color(0xFF002F6C),
        secondary: Color(0xFFFFB81C),
        textColor: Color(0xFF002F6C),
      ),
      'UA': _AirlineBrand(
        name: 'United Airlines',
        code: 'UA',
        primary: Color(0xFF002244),
        secondary: Color(0xFF00A3E0),
        textColor: Color(0xFF002244),
      ),
      'WN': _AirlineBrand(
        name: 'Southwest Airlines',
        code: 'WN',
        primary: Color(0xFF304CB2),
        secondary: Color(0xFFEAAA00),
        textColor: Color(0xFF304CB2),
      ),
    };
    return overrides[code] ??
        _AirlineBrand(
          name: 'flightprint Air',
          code: code.isEmpty ? 'FP' : code,
          primary: fallback,
          secondary: const Color(0xFF0E766E),
          textColor: const Color(0xFF06242F),
        );
  }
}
