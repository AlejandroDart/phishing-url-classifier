import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.title,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onNavigate,
  });

  final String title;
  final bool isDarkMode;
  final Future<void> Function() onToggleTheme;
  final ValueChanged<int> onNavigate;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  late Future<DashboardStats> _futureStats;

  bool? _isServerOnline;

  @override
  void initState() {
    super.initState();
    _isServerOnline = null;
    _futureStats = _loadStatsAndStatus();
  }

  Future<DashboardStats> _loadStatsAndStatus() async {
    try {
      final stats = await _statsService.fetchDashboardStats();

      if (mounted) {
        setState(() {
          _isServerOnline = true;
        });
      }

      return stats;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServerOnline = false;
        });
      }
      rethrow;
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isServerOnline = null;
      _futureStats = _loadStatsAndStatus();
    });

    try {
      await _futureStats;
    } catch (_) {
      // El error ya lo maneja el FutureBuilder.
    }
  }

  Color _backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF030B16) : const Color(0xFFF4F7FB);

  Color _panelColor(bool isDark) =>
      isDark ? const Color(0xFF071423) : Colors.white;

  Color _primaryGlow(bool isDark) =>
      isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);

  Color _secondaryGlow(bool isDark) =>
      isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);

  Color _dangerColor(bool isDark) =>
      isDark ? const Color(0xFFFF2D78) : const Color(0xFFD81B60);

  Color _warningColor(bool isDark) =>
      isDark ? const Color(0xFFFFB020) : const Color(0xFFF39C12);

  Color _successColor(bool isDark) =>
      isDark ? const Color(0xFF19F6A5) : const Color(0xFF00A86B);

  Color _textColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF102030);

  Color _subtleTextColor(bool isDark) =>
      isDark ? const Color(0xFF6FB6FF) : const Color(0xFF376D9A);

  BoxDecoration _glowBox({
    required bool isDark,
    required double radius,
  }) {
    final base = _panelColor(isDark);
    final glow = _primaryGlow(isDark);

    return BoxDecoration(
      color: base.withValues(alpha: isDark ? 0.82 : 0.95),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glow.withValues(alpha: isDark ? 0.55 : 0.35),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: glow.withValues(alpha: isDark ? 0.18 : 0.08),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    );
  }

  String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final positionFromEnd = text.length - i;
      buffer.write(text[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Tiempo desconocido';

    final now = DateTime.now();
    final localDate = date;
    final difference = now.difference(localDate);

    if (difference.inSeconds < 60) return 'Hace ${difference.inSeconds}s';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    if (difference.inDays < 7) return 'Hace ${difference.inDays} d';

    return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}';
  }

  _PredictionUiState _predictionUi(RecentPrediction item, bool isDark) {
    final prob = item.probability;

    if (item.label.toLowerCase() == 'phishing' || prob >= 0.75) {
      return _PredictionUiState(
        label: 'PHISHING',
        color: _dangerColor(isDark),
        icon: Icons.close_rounded,
      );
    }

    if (prob >= 0.35) {
      return _PredictionUiState(
        label: 'SOSPECHOSA',
        color: _warningColor(isDark),
        icon: Icons.warning_amber_rounded,
      );
    }

    return _PredictionUiState(
      label: 'SEGURA',
      color: _successColor(isDark),
      icon: Icons.check_rounded,
    );
  }

  Widget _buildBackgroundGrid(bool isDark) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: GridPainter(
          lineColor: isDark
              ? const Color(0xFF0D2A4D).withValues(alpha: 0.45)
              : const Color(0xFFB8D3EA).withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _buildServerStatusBadge(bool isDark) {
    final bool isChecking = _isServerOnline == null;
    final bool isOnline = _isServerOnline == true;

    final Color statusColor = isChecking
        ? _warningColor(isDark)
        : isOnline
            ? _successColor(isDark)
            : _dangerColor(isDark);

    final String statusText = isChecking
        ? '........'
        : isOnline
            ? 'EN LÍNEA'
            : 'OFFLINE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _glowBox(isDark: isDark, radius: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: _backgroundColor(isDark).withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(
            color: _primaryGlow(isDark).withValues(alpha: 0.20),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: _glowBox(isDark: isDark, radius: 14),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/images/phishing.png'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: _primaryGlow(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: _primaryGlow(isDark).withValues(alpha: 0.55),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
            _buildServerStatusBadge(isDark),
            const SizedBox(width: 10),
            IconButton(
              tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
              onPressed: () async {
                await widget.onToggleTheme();
              },
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: _secondaryGlow(isDark),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(bool isDark, DashboardStats stats) {
    final progress = stats.totalAnalysis == 0
        ? 0.0
        : (stats.totalAnalysis / 1000).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL URLS:',
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: 16,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.bar_chart_rounded,
                color: _primaryGlow(isDark),
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatNumber(stats.totalAnalysis),
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'RIESGO ${_formatPercent(stats.phishingRatio)}',
                style: TextStyle(
                  color: _successColor(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: _primaryGlow(isDark).withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryGlow(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioCard(bool isDark, DashboardStats stats) {
    final malicious = stats.phishingRatio.clamp(0.0, 1.0);
    final benign = (1 - malicious).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Column(
        children: [
          Text(
            'RATIO DE AMENAZAS:',
            style: TextStyle(
              color: _subtleTextColor(isDark),
              fontSize: 16,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 170,
                  child: CustomPaint(
                    painter: DonutChartPainter(
                      progress: malicious,
                      primaryColor: _primaryGlow(isDark),
                      trackColor: _primaryGlow(isDark).withValues(alpha: 0.14),
                    ),
                    child: Center(
                      child: Text(
                        _formatPercent(malicious),
                        style: TextStyle(
                          color: _primaryGlow(isDark),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                      color: _primaryGlow(isDark),
                      label: 'MALICIOSAS',
                      value: _formatPercent(malicious),
                      textColor: _textColor(isDark),
                    ),
                    const SizedBox(height: 16),
                    _LegendItem(
                      color: const Color(0xFF92A7C6),
                      label: 'SEGURAS',
                      value: _formatPercent(benign),
                      textColor: _textColor(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Relación actual según las predicciones almacenadas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subtleTextColor(isDark),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistoryCard(bool isDark, DashboardStats stats) {
    return Container(
      width: double.infinity,
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  color: _primaryGlow(isDark),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'HISTORIAL DE ANÁLISIS:',
                    style: TextStyle(
                      color: _primaryGlow(isDark),
                      fontSize: 16,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: _primaryGlow(isDark).withValues(alpha: 0.14),
          ),
          if (stats.recentPredictions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No hay análisis recientes.',
                style: TextStyle(
                  color: _subtleTextColor(isDark),
                  fontSize: 15,
                ),
              ),
            )
          else
            ...stats.recentPredictions.map((item) {
              final ui = _predictionUi(item, isDark);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ui.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            ui.icon,
                            color: ui.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textColor(isDark),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Detectada: ${_timeAgo(item.createdAt)} • Puntaje: ${item.probability.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: _subtleTextColor(isDark),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: ui.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ui.color.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            ui.label,
                            style: TextStyle(
                              color: ui.color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item != stats.recentPredictions.last)
                    Divider(
                      height: 1,
                      color: _primaryGlow(isDark).withValues(alpha: 0.10),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDailyTrendCard(bool isDark, DashboardStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TENDENCIA DIARIA:',
                  style: TextStyle(
                    color: _primaryGlow(isDark),
                    fontSize: 16,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MiniLegendDot(
                color: _primaryGlow(isDark),
                label: 'Escaneos',
                textColor: _subtleTextColor(isDark),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: stats.dailyActivity.isEmpty
                ? Center(
                    child: Text(
                      'No hay actividad diaria disponible.',
                      style: TextStyle(
                        color: _subtleTextColor(isDark),
                        fontSize: 14,
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: DailyTrendPainter(
                      items: stats.dailyActivity,
                      lineColor: _primaryGlow(isDark),
                      gridColor: _primaryGlow(isDark).withValues(alpha: 0.10),
                      textColor: _subtleTextColor(isDark),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: _primaryGlow(isDark), size: 20),
            const SizedBox(width: 24),
            Icon(Icons.key_outlined, color: _primaryGlow(isDark), size: 20),
            const SizedBox(width: 24),
            Icon(Icons.fingerprint, color: _primaryGlow(isDark), size: 20),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '© 2026 Alejandro Mayró Lena',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _primaryGlow(isDark),
            fontSize: 13,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildDashboard(bool isDark, DashboardStats stats) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        child: Column(
          children: [
            _buildTotalCard(isDark, stats),
            const SizedBox(height: 22),
            _buildRatioCard(isDark, stats),
            const SizedBox(height: 22),
            _buildRecentHistoryCard(isDark, stats),
            const SizedBox(height: 22),
            _buildDailyTrendCard(isDark, stats),
            _buildBottomInfo(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 26),
      decoration: BoxDecoration(
        color: _backgroundColor(isDark).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: _primaryGlow(isDark).withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: () {
                widget.onNavigate(0);
              },
              icon: Icon(
                Icons.shield_rounded,
                color: _primaryGlow(isDark),
                size: 28,
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _primaryGlow(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _primaryGlow(isDark).withValues(alpha: 0.25),
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    widget.onNavigate(1);
                  },
                  icon: Icon(
                    Icons.bar_chart_rounded,
                    color: _primaryGlow(isDark),
                    size: 28,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.history_rounded,
                color: _primaryGlow(isDark),
                size: 28,
              ),
            ),
            IconButton(
              onPressed: () {
                widget.onNavigate(2);
              },
              icon: Icon(
                Icons.settings_rounded,
                color: _primaryGlow(isDark),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _backgroundColor(isDark),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundGrid(isDark)),
          Column(
            children: [
              _buildTopBar(isDark),
              Expanded(
                child: FutureBuilder<DashboardStats>(
                  future: _futureStats,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: _primaryGlow(isDark),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: _glowBox(isDark: isDark, radius: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: _dangerColor(isDark),
                                  size: 48,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No se pudieron cargar las estadísticas.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textColor(isDark),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _subtleTextColor(isDark),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reintentar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryGlow(isDark),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final stats = snapshot.data!;
                    return _buildDashboard(isDark, stats);
                  },
                ),
              ),
              _buildBottomNavigation(isDark),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionUiState {
  final String label;
  final Color color;
  final IconData icon;

  _PredictionUiState({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.textColor,
  });

  final Color color;
  final String label;
  final String value;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MiniLegendDot extends StatelessWidget {
  const _MiniLegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  DonutChartPainter({
    required this.progress,
    required this.primaryColor,
    required this.trackColor,
  });

  final double progress;
  final Color primaryColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class DailyTrendPainter extends CustomPainter {
  DailyTrendPainter({
    required this.items,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<DailyActivity> items;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 14.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (items.isEmpty || chartWidth <= 0 || chartHeight <= 0) return;

    final maxY = items.map((e) => e.total).fold<int>(0, math.max).toDouble();
    final safeMaxY = maxY <= 0 ? 1.0 : maxY;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.20)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final points = <Offset>[];

    for (int i = 0; i < items.length; i++) {
      final dx = leftPadding +
          (items.length == 1
              ? chartWidth / 2
              : (chartWidth / (items.length - 1)) * i);

      final normalized = items[i].total / safeMaxY;
      final dy = topPadding + chartHeight - (normalized * chartHeight);

      points.add(Offset(dx, dy));
    }

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 5, pointPaint);
    }

    const labelStyleBase = TextStyle(
      fontSize: 11,
      letterSpacing: 1,
    );

    for (int i = 0; i < items.length; i++) {
      final currentItem = items[i];
      final day = currentItem.date == null
          ? '--'
          : const [
              'LUN',
              'MAR',
              'MIÉ',
              'JUE',
              'VIE',
              'SÁB',
              'DOM'
            ][currentItem.date!.weekday - 1];

      final tp = TextPainter(
        text: TextSpan(
          text: day,
          style: labelStyleBase.copyWith(color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          points[i].dx - tp.width / 2,
          size.height - bottomPadding + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DailyTrendPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

class GridPainter extends CustomPainter {
  GridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 28.0;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}