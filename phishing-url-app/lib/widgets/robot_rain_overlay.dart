import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class RobotRainController {
  RobotRainController._();

  static final RobotRainController instance = RobotRainController._();
  final ValueNotifier<int> _trigger = ValueNotifier<int>(0);

  void start() {
    _trigger.value++;
  }
}

class RobotRainTrigger extends StatefulWidget {
  const RobotRainTrigger({super.key, required this.child});

  final Widget child;

  @override
  State<RobotRainTrigger> createState() => _RobotRainTriggerState();
}

class _RobotRainTriggerState extends State<RobotRainTrigger> {
  bool _pressed = false;

  Future<void> _activate() async {
    setState(() {
      _pressed = true;
    });
    RobotRainController.instance.start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.86 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.68 : 1,
        duration: const Duration(milliseconds: 110),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _activate,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class RobotRainOverlay extends StatefulWidget {
  const RobotRainOverlay({
    super.key,
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  State<RobotRainOverlay> createState() => _RobotRainOverlayState();
}

class _RobotRainOverlayState extends State<RobotRainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final math.Random _random = math.Random();
  final Set<int> _removedParticles = <int>{};
  List<_RobotParticle> _particles = const [];
  Timer? _resultTimer;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishRain();
        }
      });
    RobotRainController.instance._trigger.addListener(_startRain);
  }

  @override
  void dispose() {
    RobotRainController.instance._trigger.removeListener(_startRain);
    _resultTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startRain() {
    _resultTimer?.cancel();
    setState(() {
      _showResult = false;
      _removedParticles.clear();
      _particles = List.generate(22, (index) {
        final delay = _random.nextDouble() * 0.22;
        const minimumTravel = 0.68;
        final maximumTravel = 0.97 - delay;
        return _RobotParticle(
          id: index,
          horizontalPosition: _random.nextDouble(),
          delay: delay,
          travelFactor: minimumTravel +
              _random.nextDouble() * (maximumTravel - minimumTravel),
          size: 24 + _random.nextDouble() * 18,
          rotation: (_random.nextDouble() - 0.5) * 1.4,
          drift: (_random.nextDouble() - 0.5) * 42,
        );
      });
    });
    _animationController.forward(from: 0);
  }

  void _finishRain() {
    if (!mounted) return;
    setState(() {
      _showResult = true;
    });
    _resultTimer?.cancel();
    _resultTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() {
        _particles = const [];
        _removedParticles.clear();
        _showResult = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final robotColor =
        widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_particles.isNotEmpty && !_showResult)
              const Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: Colors.transparent,
                ),
              ),
            if (_particles.isNotEmpty)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 76,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xE6071423)
                            : const Color(0xEEFFFFFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: robotColor.withValues(alpha: 0.52),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: robotColor.withValues(alpha: 0.16),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: (_showResult
                                          ? const Color(0xFFFFC857)
                                          : robotColor)
                                      .withValues(alpha: 0.13),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _showResult
                                      ? Icons.emoji_events_rounded
                                      : Icons.smart_toy_rounded,
                                  color: _showResult
                                      ? const Color(0xFFFFC857)
                                      : robotColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 132,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _showResult
                                          ? 'RESULTADO FINAL'
                                          : 'ROBOTS CAPTURADOS',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: widget.isDark
                                            ? Colors.white
                                            : const Color(0xFF102030),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_removedParticles.length} / ${_particles.length}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _showResult
                                            ? const Color(0xFFFFC857)
                                            : robotColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 170,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value: _particles.isEmpty
                                    ? 0
                                    : _removedParticles.length /
                                        _particles.length,
                                backgroundColor: robotColor.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _showResult
                                      ? const Color(0xFFFFC857)
                                      : robotColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_particles.isNotEmpty && !_showResult)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    children: _particles.where((particle) {
                      return !_removedParticles.contains(particle.id);
                    }).map((particle) {
                      final rawProgress =
                          (_animationController.value - particle.delay) /
                              particle.travelFactor;
                      final progress = rawProgress.clamp(0.0, 1.0);
                      final easedProgress = Curves.easeIn.transform(progress);
                      final top = -particle.size +
                          easedProgress *
                              (constraints.maxHeight + particle.size + 60);
                      final baseLeft = particle.horizontalPosition *
                          (constraints.maxWidth - particle.size);
                      final left = (baseLeft +
                              math.sin(progress * math.pi * 2) * particle.drift)
                          .clamp(0.0, constraints.maxWidth - particle.size);
                      final opacity = rawProgress <= 0 || rawProgress >= 1
                          ? 0.0
                          : (1 - math.max(0.0, progress - 0.82) / 0.18)
                              .clamp(0.0, 1.0);

                      return Positioned(
                        left: left,
                        top: top,
                        child: Opacity(
                          opacity: opacity,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _removedParticles.add(particle.id);
                              });
                            },
                            child: Transform.rotate(
                              angle: particle.rotation * progress,
                              child: Container(
                                width: particle.size,
                                height: particle.size,
                                decoration: BoxDecoration(
                                  color: robotColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: robotColor.withValues(alpha: 0.65),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: robotColor.withValues(alpha: 0.24),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.smart_toy_rounded,
                                  color: robotColor,
                                  size: particle.size * 0.64,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _RobotParticle {
  const _RobotParticle({
    required this.id,
    required this.horizontalPosition,
    required this.delay,
    required this.travelFactor,
    required this.size,
    required this.rotation,
    required this.drift,
  });

  final int id;
  final double horizontalPosition;
  final double delay;
  final double travelFactor;
  final double size;
  final double rotation;
  final double drift;
}
