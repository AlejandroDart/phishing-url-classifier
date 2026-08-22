import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/app_content_width.dart';
import '../widgets/robot_rain_overlay.dart';
import '../widgets/shap_explanation_summary.dart';

import '../models/local_prediction.dart';
import '../services/local_prediction_repository.dart';
import '../services/api_service.dart';

enum HistoryDateFilter { all, today, last7Days, last30Days }

enum HistorySortOrder { newest, oldest }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
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
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  HistoryDateFilter _selectedDateFilter = HistoryDateFilter.all;
  HistorySortOrder _selectedSortOrder = HistorySortOrder.newest;
  int? _selectedLimit = 5;

  final LocalPredictionRepository _repository = LocalPredictionRepository();

  List<LocalPrediction>? _cachedItems;
  String? _loadError;
  bool _isRefreshingHistory = false;
  final ScrollController _historyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void dispose() {
    _historyScrollController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final previousOffset = _historyScrollController.hasClients
        ? _historyScrollController.offset
        : 0.0;

    setState(() {
      _isRefreshingHistory = true;
      _loadError = null;
    });

    try {
      final items = await _repository.getPredictions();

      if (!mounted) return;

      setState(() {
        _cachedItems = items;
        _isRefreshingHistory = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_historyScrollController.hasClients) return;

        final safeOffset = previousOffset.clamp(
          0.0,
          _historyScrollController.position.maxScrollExtent,
        );

        _historyScrollController.jumpTo(safeOffset);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isRefreshingHistory = false;
        if (_cachedItems == null) {
          _loadError = 'No fue posible abrir el historial local del navegador.';
        }
      });
    }
  }

  Widget _buildLoadError(bool isDark) {
    final accentColor = _primaryGlow(isDark);

    return Center(
      child: SingleChildScrollView(
        padding: AppDesign.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            width: double.infinity,
            padding: AppDesign.cardPadding,
            decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppDesign.cardHeaderIconSize,
                  height: AppDesign.cardHeaderIconSize,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    Icons.storage_rounded,
                    color: accentColor,
                    size: AppDesign.sectionIconSize,
                  ),
                ),
                const SizedBox(height: AppDesign.gapCompact),
                Text(
                  'HISTORIAL NO DISPONIBLE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontSectionTitle,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppDesign.gapSmall),
                Text(
                  _loadError ?? 'No fue posible cargar el historial local.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: AppDesign.fontSubtitle,
                    height: AppDesign.bodyLineHeight,
                  ),
                ),
                const SizedBox(height: AppDesign.gapMedium),
                FilledButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: _backgroundColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    await _repository.deletePrediction(id);
    await reload();
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: _panelColor(isDark),
          title: Text(
            'Borrar historial',
            style: TextStyle(
              color: _textColor(isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Seguro que quieres borrar todo el historial local?',
            style: TextStyle(color: _subtleTextColor(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: _primaryGlow(isDark)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Borrar',
                style: TextStyle(color: _dangerColor(isDark)),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _repository.clearPredictions();
    await reload();
  }

  List<LocalPrediction> _filteredItems(List<LocalPrediction> items) {
    final now = DateTime.now();

    List<LocalPrediction> filtered = items.where((item) {
      final createdAt = item.createdAt;

      switch (_selectedDateFilter) {
        case HistoryDateFilter.today:
          return createdAt.year == now.year &&
              createdAt.month == now.month &&
              createdAt.day == now.day;

        case HistoryDateFilter.last7Days:
          return createdAt.isAfter(now.subtract(const Duration(days: 7)));

        case HistoryDateFilter.last30Days:
          return createdAt.isAfter(now.subtract(const Duration(days: 30)));

        case HistoryDateFilter.all:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      if (_selectedSortOrder == HistorySortOrder.newest) {
        return b.createdAt.compareTo(a.createdAt);
      }

      return a.createdAt.compareTo(b.createdAt);
    });

    if (_selectedLimit != null && filtered.length > _selectedLimit!) {
      filtered = filtered.take(_selectedLimit!).toList();
    }

    return filtered;
  }

  String _dateFilterLabel(HistoryDateFilter filter) {
    switch (filter) {
      case HistoryDateFilter.all:
        return 'Todos';
      case HistoryDateFilter.today:
        return 'Hoy';
      case HistoryDateFilter.last7Days:
        return 'Últimos 7 días';
      case HistoryDateFilter.last30Days:
        return 'Últimos 30 días';
    }
  }

  String _sortOrderLabel(HistorySortOrder order) {
    switch (order) {
      case HistorySortOrder.newest:
        return 'Más recientes';
      case HistorySortOrder.oldest:
        return 'Más antiguos';
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

  Color _successColor(bool isDark) =>
      isDark ? const Color(0xFF19F6A5) : const Color(0xFF00A86B);

  Color _textColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF102030);

  Color _subtleTextColor(bool isDark) =>
      isDark ? const Color(0xFF6FB6FF) : const Color(0xFF376D9A);

  BoxDecoration _glowBox({required bool isDark, required double radius}) {
    final glow = _primaryGlow(isDark);

    return BoxDecoration(
      color: _panelColor(isDark).withValues(alpha: isDark ? 0.82 : 0.95),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isPhishing(LocalPrediction item) {
    return item.label.toLowerCase() == 'phishing' || item.probability >= 0.5;
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

  Widget _buildFilters(bool isDark) {
    final accentColor = _primaryGlow(isDark);
    final surfaceColor = _panelColor(isDark);

    InputDecoration filterDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _subtleTextColor(isDark),
          fontSize: AppDesign.fontCaption,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        prefixIcon: Icon(icon, color: accentColor, size: 21),
        filled: true,
        fillColor: accentColor.withValues(alpha: isDark ? 0.055 : 0.035),
        contentPadding: AppDesign.controlPadding,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(AppDesign.radiusControl),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 1.4),
          borderRadius: BorderRadius.circular(AppDesign.radiusControl),
        ),
      );
    }

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
                  Icons.tune_rounded,
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
                      'FILTROS:',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: AppDesign.fontSectionTitle,
                        letterSpacing: AppDesign.cardTitleLetterSpacing,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      'PERSONALIZA TU HISTORIAL',
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
            ],
          ),
          const SizedBox(height: AppDesign.gapMedium),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDesign.gapCompact),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<HistoryDateFilter>(
                  initialValue: _selectedDateFilter,
                  dropdownColor: surfaceColor,
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                  icon: Icon(Icons.expand_more_rounded, color: accentColor),
                  decoration: filterDecoration(
                    'Rango de fechas',
                    Icons.calendar_month_rounded,
                  ),
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontBody,
                  ),
                  items: HistoryDateFilter.values.map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(_dateFilterLabel(filter)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedDateFilter = value;
                    });
                  },
                ),
                const SizedBox(height: AppDesign.gapItem),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedLimit,
                  dropdownColor: surfaceColor,
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                  icon: Icon(Icons.expand_more_rounded, color: accentColor),
                  decoration: filterDecoration(
                    'Cantidad a mostrar',
                    Icons.format_list_numbered_rounded,
                  ),
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontBody,
                  ),
                  items: const [
                    DropdownMenuItem<int?>(value: 5, child: Text('5 últimas')),
                    DropdownMenuItem<int?>(
                        value: 10, child: Text('10 últimas')),
                    DropdownMenuItem<int?>(
                        value: 15, child: Text('15 últimas')),
                    DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedLimit = value;
                    });
                  },
                ),
                const SizedBox(height: AppDesign.gapItem),
                DropdownButtonFormField<HistorySortOrder>(
                  initialValue: _selectedSortOrder,
                  dropdownColor: surfaceColor,
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                  icon: Icon(Icons.expand_more_rounded, color: accentColor),
                  decoration:
                      filterDecoration('Orden', Icons.swap_vert_rounded),
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontBody,
                  ),
                  items: HistorySortOrder.values.map((order) {
                    return DropdownMenuItem(
                      value: order,
                      child: Text(_sortOrderLabel(order)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedSortOrder = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(bool isDark, List<LocalPrediction> items) {
    final accentColor = _primaryGlow(isDark);
    final dangerColor = _dangerColor(isDark);

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
                  Icons.history_rounded,
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
                      'HISTORIAL LOCAL:',
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
                width: AppDesign.cardHeaderIconSize,
                height: AppDesign.cardHeaderIconSize,
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dangerColor.withValues(alpha: 0.28),
                  ),
                ),
                child: IconButton(
                  tooltip: 'Borrar historial local',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: items.isEmpty ? null : _confirmClearHistory,
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: items.isEmpty
                        ? dangerColor.withValues(alpha: 0.35)
                        : dangerColor,
                    size: AppDesign.listIconSize,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapMedium),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: AppDesign.itemPadding,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                border: Border.all(color: accentColor.withValues(alpha: 0.12)),
              ),
              child: Text(
                'No hay historial local guardado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subtleTextColor(isDark),
                  fontSize: AppDesign.fontSubtitle,
                ),
              ),
            )
          else
            ...items.map((item) {
              final phishing = _isPhishing(item);
              final color =
                  phishing ? _dangerColor(isDark) : _successColor(isDark);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesign.gapCompact),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                  onTap: () => _showLocalPredictionDetails(item, isDark),
                  child: Container(
                    padding: AppDesign.listItemPadding,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(
                        AppDesign.radiusControl,
                      ),
                      border: Border.all(
                        color: color.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: AppDesign.listLeadingSize,
                          height: AppDesign.listLeadingSize,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            phishing
                                ? Icons.close_rounded
                                : Icons.check_rounded,
                            color: color,
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
                                  fontWeight: FontWeight.w700,
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
                            color: dangerColor.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dangerColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: IconButton(
                            tooltip: 'Eliminar del historial',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: item.id == null
                                ? null
                                : () => _deleteItem(item.id!),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: dangerColor,
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
        const SizedBox(height: AppDesign.gapLarge),
      ],
    );
  }

  Widget _buildHistoryContent(bool isDark, List<LocalPrediction> items) {
    final filteredItems = _filteredItems(items);

    return RefreshIndicator(
      onRefresh: reload,
      child: SingleChildScrollView(
        controller: _historyScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppDesign.pagePadding,
        child: AppContentWidth(
          child: Column(
            children: [
              _buildFilters(isDark),
              const SizedBox(height: AppDesign.gapBetweenCards),
              _buildHistoryCard(isDark, filteredItems),
              _buildBottomInfo(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    const selectedIndex = 2;

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

  void _showLocalPredictionDetails(LocalPrediction item, bool isDark) {
    final phishing = _isPhishing(item);
    final classification = phishing ? 'PHISHING' : 'SEGURA';
    final statusColor = phishing ? _dangerColor(isDark) : _successColor(isDark);
    final statusIcon = phishing ? Icons.close_rounded : Icons.check_rounded;
    final explanationFuture = _resolveLocalExplanation(item);
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
                    decoration: _glowBox(
                      isDark: isDark,
                      radius: AppDesign.radiusDialog,
                    ),
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
                          const SizedBox(height: AppDesign.gapMedium),
                          Row(
                            children: [
                              Icon(
                                statusIcon,
                                color: statusColor,
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
                          _HistoryDetailRow(
                            label: 'URL',
                            value: item.url,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _HistoryDetailRow(
                            label: 'Clasificación',
                            value: classification,
                            textColor: statusColor,
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _HistoryDetailRow(
                            label: 'Probabilidad',
                            value:
                                '${(item.probability * 100).toStringAsFixed(2)}%',
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _HistoryDetailRow(
                            label: 'Modelo utilizado',
                            value: item.modelName,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _HistoryDetailRow(
                            label: 'Perfil de sensibilidad',
                            value: profileLabel,
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _HistoryDetailRow(
                            label: 'Umbral aplicado',
                            value:
                                '${(item.effectiveThreshold * 100).toStringAsFixed(1)}%',
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          _HistoryDetailRow(
                            label: 'Fecha',
                            value: _formatDate(item.createdAt),
                            textColor: _textColor(isDark),
                            subtleColor: _subtleTextColor(isDark),
                          ),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: explanationFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppDesign.gapContent,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _primaryGlow(isDark),
                                        ),
                                      ),
                                      const SizedBox(width: AppDesign.gapSmall),
                                      Text(
                                        'Preparando explicabilidad',
                                        style: TextStyle(
                                          color: _subtleTextColor(isDark),
                                          fontSize: AppDesign.fontLabel,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ShapExplanationSummary(
                                explanation: snapshot.data,
                                textColor: _textColor(isDark),
                                subtleColor: _subtleTextColor(isDark),
                                accentColor: _primaryGlow(isDark),
                                increaseColor: _dangerColor(isDark),
                                decreaseColor: _successColor(isDark),
                              );
                            },
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

  Future<Map<String, dynamic>?> _resolveLocalExplanation(
    LocalPrediction item,
  ) async {
    final explanation = decodeStoredExplanation(item.explanation);
    if (explanation == null) return null;
    if (explanation['shap'] is Map) return explanation;

    final rawFeatures = explanation['features'];
    if (rawFeatures is! Map) return explanation;
    final shap = await explainStoredFeatures(
      Map<String, dynamic>.from(rawFeatures),
      item.probability,
      item.modelId,
    );
    if (shap == null) return explanation;

    final enriched = Map<String, dynamic>.from(explanation)..['shap'] = shap;
    if (item.id != null) {
      await _repository.updateExplanation(item.id!, jsonEncode(enriched));
    }
    return enriched;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = _cachedItems;

    return Scaffold(
      backgroundColor: _backgroundColor(isDark),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundGrid(isDark)),
          Column(
            children: [
              _buildTopBar(isDark),
              Expanded(
                child: items == null
                    ? _loadError != null
                        ? _buildLoadError(isDark)
                        : Center(
                            child: CircularProgressIndicator(
                              color: _primaryGlow(isDark),
                            ),
                          )
                    : Stack(
                        children: [
                          _buildHistoryContent(isDark, items),
                          if (_isRefreshingHistory)
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
                                    const SizedBox(width: AppDesign.gapSmall),
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

class _HistoryDetailRow extends StatelessWidget {
  const _HistoryDetailRow({
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
