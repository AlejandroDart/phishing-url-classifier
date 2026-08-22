import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/app_content_width.dart';
import '../widgets/robot_rain_overlay.dart';
import '../widgets/shap_explanation_summary.dart';

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
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  Future<DashboardStats>? _futureStats;

  DashboardStats? _cachedStats;
  bool _isRefreshingDashboard = false;
  final ScrollController _dashboardScrollController = ScrollController();

  bool? _isServerOnline;

  @override
  void initState() {
    super.initState();
    _isServerOnline = null;
    _futureStats = null;
  }

  @override
  void dispose() {
    _dashboardScrollController.dispose();
    super.dispose();
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

  Future<void> reload() async {
    final previousOffset = _dashboardScrollController.hasClients
        ? _dashboardScrollController.offset
        : 0.0;

    final hasCachedData = _cachedStats != null;
    final future = _loadStatsAndStatus();

    setState(() {
      _isRefreshingDashboard = true;

      if (!hasCachedData) {
        _isServerOnline = null;
      }

      _futureStats = future;
    });

    try {
      final stats = await future;

      if (!mounted) return;

      setState(() {
        _cachedStats = stats;
        _isServerOnline = true;
        _isRefreshingDashboard = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_dashboardScrollController.hasClients) return;

        final safeOffset = previousOffset.clamp(
          0.0,
          _dashboardScrollController.position.maxScrollExtent,
        );

        _dashboardScrollController.jumpTo(safeOffset);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isServerOnline = false;
        _isRefreshingDashboard = false;
      });
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

  BoxDecoration _glowBox({required bool isDark, required double radius}) {
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';

    final localDate = date.toLocal();
    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
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
      padding: AppDesign.statusBadgePadding,
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
          const SizedBox(width: AppDesign.gapRegular),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: AppDesign.fontMicro,
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
      padding: AppDesign.topBarPadding,
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
            RobotRainTrigger(
              child: Container(
                width: AppDesign.topBarIconBoxSize,
                height: AppDesign.topBarIconBoxSize,
                decoration: _glowBox(
                  isDark: isDark,
                  radius: AppDesign.radiusItem,
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: _secondaryGlow(isDark),
                  size: AppDesign.topBarActionIconSize,
                ),
              ),
            ),
            const SizedBox(width: AppDesign.gapItem),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: _primaryGlow(isDark),
                  fontSize: AppDesign.fontSectionTitle,
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
            const SizedBox(width: AppDesign.gapRegular),
            IconButton(
              tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
              onPressed: () async {
                await widget.onToggleTheme();
              },
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: _secondaryGlow(isDark),
                size: AppDesign.topBarActionIconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(bool isDark, DashboardStats stats) {
    final nextMilestone = ((stats.totalAnalysis ~/ 100) + 1) * 100;
    final progress = stats.totalAnalysis / nextMilestone;
    final riskColor = stats.phishingRatio >= 0.5
        ? _dangerColor(isDark)
        : stats.phishingRatio >= 0.25
            ? _warningColor(isDark)
            : _successColor(isDark);

    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL URLS:',
                      style: TextStyle(
                        color: _primaryGlow(isDark),
                        fontSize: AppDesign.fontSectionTitle,
                        letterSpacing: AppDesign.cardTitleLetterSpacing,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapTiny),
                    Text(
                      'RESUMEN DE ACTIVIDAD GLOBAL',
                      style: TextStyle(
                        color: _subtleTextColor(isDark),
                        fontSize: AppDesign.fontMicro,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: AppDesign.topBarIconBoxSize,
                height: AppDesign.topBarIconBoxSize,
                decoration: BoxDecoration(
                  color: _primaryGlow(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: _primaryGlow(isDark),
                  size: AppDesign.metricIconSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapContent),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: AppDesign.itemPadding,
                  decoration: BoxDecoration(
                    color: _primaryGlow(isDark).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(
                      AppDesign.radiusControl,
                    ),
                    border: Border.all(
                      color: _primaryGlow(isDark).withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryGlow(isDark).withValues(alpha: 0.07),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link_rounded,
                            color: _primaryGlow(isDark),
                            size: AppDesign.smallActionIconSize,
                          ),
                          const SizedBox(width: AppDesign.gapXSmall),
                          Text(
                            'ANALIZADAS',
                            style: TextStyle(
                              color: _subtleTextColor(isDark),
                              fontSize: AppDesign.fontCaption,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesign.gapSmall),
                      Text(
                        _formatNumber(stats.totalAnalysis),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textColor(isDark),
                          fontSize: AppDesign.fontHeroMetric,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: Container(
                  padding: AppDesign.itemPadding,
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      AppDesign.radiusControl,
                    ),
                    border: Border.all(
                      color: riskColor.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: riskColor.withValues(alpha: 0.07),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: riskColor,
                            size: AppDesign.smallActionIconSize,
                          ),
                          const SizedBox(width: AppDesign.gapXSmall),
                          Text(
                            'RIESGO',
                            style: TextStyle(
                              color: _subtleTextColor(isDark),
                              fontSize: AppDesign.fontCaption,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesign.gapSmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          _formatPercent(stats.phishingRatio),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: riskColor,
                            fontSize: AppDesign.fontHeroMetric,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapContent),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDesign.gapCompact),
            decoration: BoxDecoration(
              color: _primaryGlow(isDark).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDesign.radiusCompact),
              border: Border.all(
                color: _primaryGlow(isDark).withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PRÓXIMO OBJETIVO',
                        style: TextStyle(
                          color: _subtleTextColor(isDark),
                          fontSize: AppDesign.fontMicro,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatNumber(stats.totalAnalysis)} / '
                      '${_formatNumber(nextMilestone)}',
                      style: TextStyle(
                        color: _primaryGlow(isDark),
                        fontSize: AppDesign.fontCaption,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.gapSmall),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: _primaryGlow(
                      isDark,
                    ).withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _primaryGlow(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioCard(bool isDark, DashboardStats stats) {
    final malicious = stats.phishingRatio.clamp(0.0, 1.0);
    final benign = (1 - malicious).clamp(0.0, 1.0);
    final threatColor =
        isDark ? const Color(0xFFFF6B82) : const Color(0xFFD94864);
    final safeColor =
        isDark ? const Color(0xFF36D6B1) : const Color(0xFF148B73);

    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RATIO DE AMENAZAS:',
                  style: TextStyle(
                    color: _primaryGlow(isDark),
                    fontSize: AppDesign.fontSectionTitle,
                    letterSpacing: AppDesign.cardTitleLetterSpacing,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppDesign.gapXSmall),
                Text(
                  'DISTRIBUCIÓN GLOBAL DE RESULTADOS',
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: AppDesign.fontMicro,
                    letterSpacing: AppDesign.cardSubtitleLetterSpacing,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          Column(
            children: [
              SizedBox(
                width: AppDesign.chartDonutSize + 16,
                height: AppDesign.chartDonutSize + 16,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    progress: malicious,
                    primaryColor: threatColor,
                    trackColor: safeColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatPercent(malicious),
                          style: TextStyle(
                            color: threatColor,
                            fontSize: AppDesign.fontMetric,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapXSmall),
                        Text(
                          'RIESGO GLOBAL',
                          style: TextStyle(
                            color: _subtleTextColor(isDark),
                            fontSize: AppDesign.fontMicro,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.gapMedium),
              Row(
                children: [
                  Expanded(
                    child: _RatioMetric(
                      color: threatColor,
                      icon: Icons.gpp_bad_outlined,
                      label: 'MALICIOSAS',
                      value: _formatPercent(malicious),
                      textColor: _textColor(isDark),
                    ),
                  ),
                  const SizedBox(width: AppDesign.gapCompact),
                  Expanded(
                    child: _RatioMetric(
                      color: safeColor,
                      icon: Icons.verified_user_outlined,
                      label: 'SEGURAS',
                      value: _formatPercent(benign),
                      textColor: _textColor(isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistoryCard(bool isDark, DashboardStats stats) {
    final accentColor = _primaryGlow(isDark);

    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppDesign.cardHeaderIconSize,
                height: AppDesign.cardHeaderIconSize,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.public_rounded,
                  color: accentColor,
                  size: AppDesign.sectionIconSize,
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HISTORIAL GLOBAL:',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: AppDesign.fontSectionTitle,
                        letterSpacing: AppDesign.cardTitleLetterSpacing,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      'ÚLTIMOS ANÁLISIS',
                      style: TextStyle(
                        color: _subtleTextColor(isDark),
                        fontSize: AppDesign.fontMicro,
                        letterSpacing: AppDesign.cardSubtitleLetterSpacing,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.gapCompact,
                  vertical: AppDesign.gapSmall,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                ),
                child: Text(
                  '${stats.recentPredictions.length}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: AppDesign.fontLabel,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapMedium),
          if (stats.recentPredictions.isEmpty)
            Container(
              width: double.infinity,
              padding: AppDesign.itemPadding,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                border: Border.all(color: accentColor.withValues(alpha: 0.12)),
              ),
              child: Text(
                'No hay análisis recientes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subtleTextColor(isDark),
                  fontSize: AppDesign.fontSubtitle,
                ),
              ),
            )
          else
            ...stats.recentPredictions.map((item) {
              final ui = _predictionUi(item, isDark);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesign.gapCompact),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                  onTap: () => _showPredictionDetails(item, isDark),
                  child: Container(
                    padding: AppDesign.listItemPadding,
                    decoration: BoxDecoration(
                      color: ui.color.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(
                        AppDesign.radiusControl,
                      ),
                      border: Border.all(
                        color: ui.color.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: AppDesign.listLeadingSize,
                          height: AppDesign.listLeadingSize,
                          decoration: BoxDecoration(
                            color: ui.color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            ui.icon,
                            color: ui.color,
                            size: AppDesign.listIconSize,
                          ),
                        ),
                        const SizedBox(width: AppDesign.gapItem),
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
                                  fontSize: AppDesign.fontSubtitle,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppDesign.gapSmall),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: _subtleTextColor(isDark),
                                    size: 15,
                                  ),
                                  const SizedBox(width: AppDesign.gapXSmall),
                                  Expanded(
                                    child: Text(
                                      _formatDate(item.createdAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _subtleTextColor(isDark),
                                        fontSize: AppDesign.fontLabel,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDesign.gapCompact),
                        Container(
                          width: AppDesign.listLeadingSize,
                          height: AppDesign.listLeadingSize,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: IconButton(
                            tooltip: 'Ver detalles',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _showPredictionDetails(item, isDark),
                            icon: Icon(
                              Icons.visibility_rounded,
                              color: accentColor,
                              size: AppDesign.listIconSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDailyTrendCard(bool isDark, DashboardStats stats) {
    final total = stats.dailyActivity.fold<int>(
      0,
      (sum, item) => sum + item.total,
    );
    final maximum = stats.dailyActivity.isEmpty
        ? 0
        : stats.dailyActivity.map((item) => item.total).reduce(math.max);
    final accentColor =
        isDark ? const Color(0xFF55B8FF) : const Color(0xFF176FC1);

    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TENDENCIA DIARIA:',
            style: TextStyle(
              color: _primaryGlow(isDark),
              fontSize: AppDesign.fontSectionTitle,
              letterSpacing: AppDesign.cardTitleLetterSpacing,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDesign.gapXSmall),
          Text(
            'ACTIVIDAD DE LOS ÚLTIMOS 7 DÍAS',
            style: TextStyle(
              color: _subtleTextColor(isDark),
              fontSize: AppDesign.fontMicro,
              letterSpacing: AppDesign.cardSubtitleLetterSpacing,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          Row(
            children: [
              Expanded(
                child: _TrendMetric(
                  icon: Icons.query_stats_rounded,
                  label: 'TOTAL 7 DÍAS',
                  value: _formatNumber(total),
                  color: accentColor,
                  textColor: _textColor(isDark),
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: _TrendMetric(
                  icon: Icons.trending_up_rounded,
                  label: 'MÁXIMO DIARIO',
                  value: _formatNumber(maximum),
                  color: isDark
                      ? const Color(0xFF9A8CFF)
                      : const Color(0xFF6757C8),
                  textColor: _textColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapCompact),
          Container(
            height: 224,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.055 : 0.035),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(color: accentColor.withValues(alpha: 0.16)),
            ),
            child: stats.dailyActivity.isEmpty
                ? Center(
                    child: Text(
                      'No hay actividad diaria disponible.',
                      style: TextStyle(
                        color: _subtleTextColor(isDark),
                        fontSize: AppDesign.fontBody,
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: DailyTrendPainter(
                      items: stats.dailyActivity,
                      lineColor: accentColor,
                      gridColor: accentColor.withValues(alpha: 0.10),
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
        const SizedBox(height: AppDesign.gapStandard),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              color: _primaryGlow(isDark),
              size: AppDesign.footerIconSize,
            ),
            const SizedBox(width: AppDesign.footerIconGap),
            Icon(
              Icons.key_outlined,
              color: _primaryGlow(isDark),
              size: AppDesign.footerIconSize,
            ),
            const SizedBox(width: AppDesign.footerIconGap),
            Icon(
              Icons.fingerprint,
              color: _primaryGlow(isDark),
              size: AppDesign.footerIconSize,
            ),
          ],
        ),
        const SizedBox(height: AppDesign.gapContent),
        Text(
          '© 2026 Alejandro Mayró Lena',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _primaryGlow(isDark),
            fontSize: AppDesign.fontLabel,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: AppDesign.gapContent),
      ],
    );
  }

  Widget _buildDashboard(bool isDark, DashboardStats stats) {
    return RefreshIndicator(
      onRefresh: reload,
      child: SingleChildScrollView(
        controller: _dashboardScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppDesign.pagePadding,
        child: AppContentWidth(
          child: Column(
            children: [
              _buildTotalCard(isDark, stats),
              const SizedBox(height: AppDesign.gapBetweenCards),
              _buildRatioCard(isDark, stats),
              const SizedBox(height: AppDesign.gapBetweenCards),
              _buildRecentHistoryCard(isDark, stats),
              const SizedBox(height: AppDesign.gapBetweenCards),
              _buildDailyTrendCard(isDark, stats),
              _buildBottomInfo(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    const selectedIndex = 1;

    return Container(
      padding: AppDesign.bottomNavigationPadding,
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
            _navItem(isDark, Icons.shield_rounded, 0, selectedIndex),
            _navItem(isDark, Icons.bar_chart_rounded, 1, selectedIndex),
            _navItem(isDark, Icons.history_rounded, 2, selectedIndex),
            _navItem(isDark, Icons.sports_esports_rounded, 3, selectedIndex),
            _navItem(isDark, Icons.settings_rounded, 4, selectedIndex),
          ],
        ),
      ),
    );
  }

  Widget _navItem(bool isDark, IconData icon, int index, int selectedIndex) {
    final selected = index == selectedIndex;

    return SizedBox(
      width: AppDesign.topBarIconBoxSize,
      height: AppDesign.topBarIconBoxSize,
      child: DecoratedBox(
        decoration: selected
            ? BoxDecoration(
                color: _primaryGlow(isDark).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                border: Border.all(
                  color: _primaryGlow(isDark).withValues(alpha: 0.25),
                ),
              )
            : const BoxDecoration(),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => widget.onNavigate(index),
          icon: Icon(
            icon,
            color: _primaryGlow(isDark),
            size: AppDesign.sectionIconSize,
          ),
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
                child: _futureStats == null && _cachedStats == null
                    ? Center(
                        child: Text(
                          'Abriendo dashboard...',
                          style: TextStyle(
                            color: _primaryGlow(isDark),
                            fontSize: AppDesign.fontSubtitle,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : FutureBuilder<DashboardStats>(
                        future: _futureStats,
                        initialData: _cachedStats,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              _cachedStats == null) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: _primaryGlow(isDark),
                              ),
                            );
                          }

                          if (snapshot.hasError && _cachedStats == null) {
                            return Center(
                              child: Padding(
                                padding: AppDesign.cardPadding,
                                child: Container(
                                  padding: AppDesign.cardPadding,
                                  decoration: _glowBox(
                                    isDark: isDark,
                                    radius: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: _dangerColor(isDark),
                                        size: AppDesign.emptyStateIconSize,
                                      ),
                                      const SizedBox(height: AppDesign.gapItem),
                                      Text(
                                        'No se pudieron cargar las estadísticas.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _textColor(isDark),
                                          fontSize: AppDesign.fontSectionTitle,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppDesign.gapRegular,
                                      ),
                                      Text(
                                        'Servidor no disponible.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _subtleTextColor(isDark),
                                          fontSize: AppDesign.fontLabel,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppDesign.gapStandard,
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: reload,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Reintentar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryGlow(isDark),
                                          foregroundColor: Colors.white,
                                          padding: AppDesign.buttonPadding,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppDesign.radiusControl,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final stats = snapshot.data ?? _cachedStats;

                          if (stats == null) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: _primaryGlow(isDark),
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              _buildDashboard(isDark, stats),
                              if (_isRefreshingDashboard)
                                Center(
                                  child: Container(
                                    padding: AppDesign.chipPadding,
                                    decoration: _glowBox(
                                      isDark: isDark,
                                      radius: 12,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _primaryGlow(isDark),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: AppDesign.gapSmall,
                                        ),
                                        Text(
                                          'Actualizando',
                                          style: TextStyle(
                                            color: _primaryGlow(isDark),
                                            fontSize: AppDesign.fontCaption,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
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

  void _showPredictionDetails(RecentPrediction item, bool isDark) {
    final ui = _predictionUi(item, isDark);
    final profileLabel = switch (item.sensitivityProfile) {
      'aggressive' => 'Agresivo',
      'passive' => 'Pasivo',
      _ => 'Equilibrado',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final isLandscape = mediaQuery.orientation == Orientation.landscape;

        return SafeArea(
          minimum: const EdgeInsets.all(AppDesign.gapSmall),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight =
                  constraints.maxHeight * (isLandscape ? 0.90 : 0.82);

              return Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Container(
                    margin: const EdgeInsets.all(AppDesign.gapSmall),
                    decoration: _glowBox(isDark: isDark, radius: 24),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: AppDesign.detailsSheetPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 48,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _subtleTextColor(isDark)
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(
                                    AppDesign.radiusPanel,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDesign.gapContent),
                          Row(
                            children: [
                              Icon(
                                ui.icon,
                                color: ui.color,
                                size: AppDesign.topBarActionIconSize,
                              ),
                              const SizedBox(width: AppDesign.gapCompact),
                              Expanded(
                                child: Text(
                                  'DETALLE DEL ANÁLISIS',
                                  style: TextStyle(
                                    color: _primaryGlow(isDark),
                                    fontSize: AppDesign.fontSectionTitle,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDesign.gapContent),
                          _DetailRow(
                            label: 'URL',
                            value: item.url,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _DetailRow(
                            label: 'Clasificación',
                            value: ui.label,
                            textColor: ui.color,
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _DetailRow(
                            label: 'Probabilidad',
                            value:
                                '${(item.probability * 100).toStringAsFixed(2)}%',
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _DetailRow(
                            label: 'Modelo utilizado',
                            value: item.modelName,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _DetailRow(
                            label: 'Perfil de sensibilidad',
                            value: profileLabel,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _DetailRow(
                            label: 'Umbral aplicado',
                            value:
                                '${(item.effectiveThreshold * 100).toStringAsFixed(1)}%',
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _DetailRow(
                            label: 'Fecha',
                            value: _formatDate(item.createdAt),
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          ShapExplanationSummary(
                            explanation: item.explanation,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                            accentColor: _primaryGlow(isDark),
                            increaseColor: _dangerColor(isDark),
                            decreaseColor: _successColor(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.subtleColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppDesign.chartLabelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: subtleColor,
              fontSize: AppDesign.fontCaption,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppDesign.gapXSmall),
          Text(
            value,
            maxLines: label.toUpperCase() == 'URL' ? 4 : null,
            overflow: label.toUpperCase() == 'URL'
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
            style: TextStyle(
              color: textColor,
              fontSize: AppDesign.fontSubtitle,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
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

class _RatioMetric extends StatelessWidget {
  const _RatioMetric({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.gapCompact,
        vertical: AppDesign.gapItem,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(AppDesign.radiusControl),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppDesign.smallActionIconSize),
          const SizedBox(height: AppDesign.gapSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: AppDesign.fontMicro,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: AppDesign.gapXSmall),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: AppDesign.fontPageTitle,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesign.gapCompact),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDesign.radiusCompact),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: AppDesign.compactMetricIconSize,
            height: AppDesign.compactMetricIconSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppDesign.gapSmall),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.68),
                  fontSize: AppDesign.fontMicro,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDesign.gapXSmall),
          SizedBox(
            width: double.infinity,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: AppDesign.fontPageTitle,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
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
    const stroke = 13.0;
    const segmentGap = 0.065;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke - 2;

    final basePaint = Paint()
      ..color = trackColor.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 3;

    final maliciousPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final safePaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, basePaint);

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    const startAngle = -math.pi / 2;
    final maliciousSweep = 2 * math.pi * progress;
    final safeSweep = 2 * math.pi * (1 - progress);
    final chartRect = Rect.fromCircle(center: center, radius: radius);

    if (maliciousSweep > segmentGap) {
      canvas.drawArc(
        chartRect,
        startAngle + segmentGap / 2,
        maliciousSweep - segmentGap,
        false,
        glowPaint,
      );
      canvas.drawArc(
        chartRect,
        startAngle + segmentGap / 2,
        maliciousSweep - segmentGap,
        false,
        maliciousPaint,
      );
    }

    if (safeSweep > segmentGap) {
      canvas.drawArc(
        chartRect,
        startAngle + maliciousSweep + segmentGap / 2,
        safeSweep - segmentGap,
        false,
        safePaint,
      );
    }
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
    const leftPadding = 42.0;
    const rightPadding = 12.0;
    const topPadding = 12.0;
    const bottomPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (items.isEmpty || chartWidth <= 0 || chartHeight <= 0) return;

    final maxTotal = items.map((e) => e.total).fold<int>(0, math.max);
    final tickCount = maxTotal <= 4 ? math.max(1, maxTotal) : 4;
    final tickStep = maxTotal <= 4 ? 1 : (maxTotal / tickCount).ceil();
    final axisMax = math.max(1, tickStep * tickCount).toDouble();

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final axisLabelStyle = TextStyle(
      color: textColor,
      fontSize: AppDesign.fontMicro,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i <= tickCount; i++) {
      final y = topPadding + (chartHeight / tickCount) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      final tickValue = (axisMax - (axisMax / tickCount) * i).round();
      final tickPainter = TextPainter(
        text: TextSpan(text: '$tickValue', style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tickPainter.paint(
        canvas,
        Offset(leftPadding - tickPainter.width - 8, y - tickPainter.height / 2),
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

      final normalized = items[i].total / axisMax;
      final dy = topPadding + chartHeight - (normalized * chartHeight);

      points.add(Offset(dx, dy));
    }

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];
        final middleX = (previous.dx + current.dx) / 2;
        path.cubicTo(
          middleX,
          previous.dy,
          middleX,
          current.dy,
          current.dx,
          current.dy,
        );
      }

      final areaPath = Path.from(path)
        ..lineTo(points.last.dx, topPadding + chartHeight)
        ..lineTo(points.first.dx, topPadding + chartHeight)
        ..close();
      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.015),
          ],
        ).createShader(
          Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
        );
      canvas.drawPath(areaPath, areaPaint);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }

    final pointHaloPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 8, pointHaloPaint);
      canvas.drawCircle(point, 4.5, pointPaint);

      if (items[i].total > 0) {
        final valuePainter = TextPainter(
          text: TextSpan(
            text: '${items[i].total}',
            style: TextStyle(
              color: lineColor,
              fontSize: AppDesign.fontMicro,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        valuePainter.paint(
          canvas,
          Offset(
            point.dx - valuePainter.width / 2,
            math.max(0, point.dy - valuePainter.height - 10),
          ),
        );
      }
    }

    const labelStyleBase = TextStyle(
      fontSize: AppDesign.fontMicro,
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
              'DOM',
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
        Offset(points[i].dx - tp.width / 2, size.height - bottomPadding + 10),
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
