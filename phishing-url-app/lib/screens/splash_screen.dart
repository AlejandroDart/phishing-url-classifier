import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _completionTimer = Timer(
      const Duration(milliseconds: 2400),
      widget.onComplete,
    );
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF030B16) : const Color(0xFFF4F7FB);
    final panel = isDark ? const Color(0xFF071423) : Colors.white;
    final primary = isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);
    final secondary =
        isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);
    final textColor = isDark ? Colors.white : const Color(0xFF102030);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SplashBackgroundPainter(
                gridColor: primary.withValues(alpha: isDark ? 0.15 : 0.10),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: AppDesign.pagePadding,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pulse =
                        0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 230,
                          height: 230,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size.square(230),
                                painter: _ScannerRingsPainter(
                                  progress: _controller.value,
                                  primary: primary,
                                  secondary: secondary,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.96 + pulse * 0.05,
                                child: Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    color: panel,
                                    borderRadius: BorderRadius.circular(
                                      AppDesign.radiusDialog,
                                    ),
                                    border: Border.all(
                                      color: secondary.withValues(alpha: 0.75),
                                      width: 1.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: secondary.withValues(
                                          alpha: 0.18 + pulse * 0.20,
                                        ),
                                        blurRadius: 28 + pulse * 14,
                                        spreadRadius: 3 + pulse * 3,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.smart_toy_rounded,
                                    color: secondary,
                                    size: 58,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapWide),
                        Text(
                          'LINKSHIELD AI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primary,
                            fontSize: AppDesign.fontPageTitle,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: primary.withValues(alpha: 0.45),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapCompact),
                        Text(
                          'PROTECCIÓN INTELIGENTE',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.72),
                            fontSize: AppDesign.fontCaption,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapLoose),
                        SizedBox(
                          width: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusSmall,
                            ),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              value: _controller.value,
                              backgroundColor: primary.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                secondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapCompact),
                        Text(
                          'INICIALIZANDO SISTEMA SEGURO',
                          style: TextStyle(
                            color: primary.withValues(alpha: 0.75),
                            fontSize: AppDesign.fontMicro,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  const _SplashBackgroundPainter({required this.gridColor});

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 32.0;
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashBackgroundPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

class _ScannerRingsPainter extends CustomPainter {
  const _ScannerRingsPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  final double progress;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide / 2;

    for (int index = 0; index < 3; index++) {
      final phase = (progress + index / 3) % 1.0;
      final radius = 68 + phase * (baseRadius - 68);
      final paint = Paint()
        ..color = primary.withValues(alpha: (1 - phase) * 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }

    final scannerPaint = Paint()
      ..color = secondary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 92),
      -math.pi / 2 + progress * math.pi * 2,
      math.pi / 2.8,
      false,
      scannerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerRingsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
