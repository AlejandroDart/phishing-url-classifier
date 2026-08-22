import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../models/model_option.dart';
import '../models/sensitivity_profile.dart';
import '../widgets/app_content_width.dart';
import '../widgets/robot_rain_overlay.dart';

import '../services/preferences_service.dart';
import '../services/network_diagnostic_service.dart';
import '../services/model_catalog_service.dart';
import 'model_info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.title,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onNavigate,
    required this.sensitivityProfile,
    required this.onSensitivityChanged,
    required this.globalStorageEnabled,
    required this.onGlobalStorageChanged,
  });

  final String title;
  final bool isDarkMode;
  final Future<void> Function() onToggleTheme;
  final ValueChanged<int> onNavigate;
  final SensitivityProfile sensitivityProfile;
  final Future<void> Function(SensitivityProfile) onSensitivityChanged;
  final bool globalStorageEnabled;
  final Future<void> Function(bool) onGlobalStorageChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _preferencesLoaded = false;
  bool _hapticAlerts = false;
  bool _globalStorageEnabled = false;
  String _selectedModelId = PreferencesService.defaultModelId;
  List<ModelOption> _availableModels = const [];
  bool _modelsLoading = true;
  String? _modelsError;

  final PreferencesService _preferencesService = PreferencesService();
  final NetworkDiagnosticService _networkDiagnosticService =
      const NetworkDiagnosticService();
  final ModelCatalogService _modelCatalogService = ModelCatalogService();

  bool _isTestingConnection = false;
  bool _serverOnline = false;
  String _networkStatus = 'SIN PROBAR';
  String _networkHost = '-';
  String _networkPort = '-';
  String _networkScheme = '-';
  String _networkEndpoint = '-';
  String _networkMessage = '-';
  int? _latencyMs;

  final List<String> _networkVisibleLines = [];
  final ValueNotifier<int> _networkRenderVersion = ValueNotifier<int>(0);
  List<String> _networkTargetLines = [];
  Timer? _networkTypingTimer;
  int _networkTypingLineIndex = 0;

  @override
  void initState() {
    super.initState();
    _globalStorageEnabled = widget.globalStorageEnabled;
    _initializeScreen();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.globalStorageEnabled != widget.globalStorageEnabled) {
      _globalStorageEnabled = widget.globalStorageEnabled;
    }
  }

  @override
  void dispose() {
    _networkTypingTimer?.cancel();
    _networkRenderVersion.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _loadPreferences();
    await _loadModels();
    _refreshNetworkConsole(forceRestart: true);
  }

  Future<void> _loadPreferences() async {
    final results = await Future.wait<dynamic>([
      _preferencesService.getHapticAlertsEnabled(),
      _preferencesService.getSelectedModelId(),
    ]);

    if (!mounted) return;

    setState(() {
      _hapticAlerts = results[0];
      _globalStorageEnabled = widget.globalStorageEnabled;
      _selectedModelId = results[1] as String;
      _preferencesLoaded = true;
    });
  }

  Future<void> _loadModels() async {
    if (mounted) {
      setState(() {
        _modelsLoading = true;
        _modelsError = null;
      });
    }
    try {
      final catalog = await _modelCatalogService.fetchModels();
      var selected = _selectedModelId;
      if (!catalog.models.any((model) => model.id == selected)) {
        selected = catalog.defaultModelId;
        await _preferencesService.setSelectedModelId(selected);
      }
      if (!mounted) return;
      setState(() {
        _availableModels = catalog.models;
        _selectedModelId = selected;
        _modelsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _modelsLoading = false;
        _modelsError = 'No fue posible consultar los modelos';
      });
    }
  }

  List<String> _buildNetworkLines() {
    final lines = <String>[
      '> ESTADO: $_networkStatus',
      '> HOST: $_networkHost',
      '> PUERTO: $_networkPort',
      '> PROTOCOLO: $_networkScheme',
      '> ENDPOINT: $_networkEndpoint',
    ];

    if (_latencyMs != null) {
      lines.add('> LATENCIA: $_latencyMs ms');
    }

    lines.add('> MENSAJE: $_networkMessage');

    return lines;
  }

  bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _isPrefix(List<String> shorter, List<String> longer) {
    if (shorter.length > longer.length) return false;
    for (int i = 0; i < shorter.length; i++) {
      if (shorter[i] != longer[i]) return false;
    }
    return true;
  }

  int _firstIncompleteNetworkLineIndex() {
    for (int i = 0; i < _networkTargetLines.length; i++) {
      if (i >= _networkVisibleLines.length) return i;

      final current = _networkVisibleLines[i];
      final target = _networkTargetLines[i];

      if (current != target) return i;
    }

    return _networkTargetLines.isEmpty ? 0 : _networkTargetLines.length - 1;
  }

  void _refreshNetworkConsole({bool forceRestart = false}) {
    final newLines = _buildNetworkLines();

    if (_sameLines(_networkTargetLines, newLines) && !forceRestart) return;

    final oldTarget = List<String>.from(_networkTargetLines);
    _networkTargetLines = List<String>.from(newLines);

    final shouldRestart = forceRestart ||
        _networkVisibleLines.isEmpty ||
        !_isPrefix(oldTarget, newLines);

    if (shouldRestart) {
      _networkTypingTimer?.cancel();
      _networkVisibleLines
        ..clear()
        ..add('');
      _networkTypingLineIndex = 0;

      _networkRenderVersion.value++;
      _startNetworkTyping();
      return;
    }

    _networkTypingTimer?.cancel();
    _networkTypingLineIndex = _firstIncompleteNetworkLineIndex();

    while (_networkVisibleLines.length <= _networkTypingLineIndex) {
      _networkVisibleLines.add('');
    }

    _networkRenderVersion.value++;
    _startNetworkTyping();
  }

  void _startNetworkTyping() {
    _networkTypingTimer?.cancel();

    _networkTypingTimer = Timer.periodic(const Duration(milliseconds: 32), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_networkTypingLineIndex >= _networkTargetLines.length) {
        timer.cancel();
        return;
      }

      while (_networkVisibleLines.length <= _networkTypingLineIndex) {
        _networkVisibleLines.add('');
      }

      final targetLine = _networkTargetLines[_networkTypingLineIndex];
      final currentLine = _networkVisibleLines[_networkTypingLineIndex];

      if (currentLine.length < targetLine.length) {
        final nextLength = math.min(currentLine.length + 2, targetLine.length);
        _networkVisibleLines[_networkTypingLineIndex] = targetLine.substring(
          0,
          nextLength,
        );
        _networkRenderVersion.value++;
        return;
      }

      if (_networkTypingLineIndex < _networkTargetLines.length - 1) {
        _networkTypingLineIndex++;

        while (_networkVisibleLines.length <= _networkTypingLineIndex) {
          _networkVisibleLines.add('');
        }
        return;
      }

      timer.cancel();
    });
  }

  Future<void> _testServerConnection() async {
    if (_isTestingConnection) return;

    setState(() {
      _isTestingConnection = true;
      _serverOnline = false;
      _networkStatus = 'PROBANDO...';
      _networkHost = '-';
      _networkPort = '-';
      _networkScheme = '-';
      _networkEndpoint = '-';
      _networkMessage = 'Verificando disponibilidad del backend...';
      _latencyMs = null;
    });

    _refreshNetworkConsole(forceRestart: true);

    final result = await _networkDiagnosticService.testConnection();

    if (!mounted) return;

    setState(() {
      _isTestingConnection = false;
      _serverOnline = result.isOnline;
      _networkStatus = result.statusText;
      _networkHost = result.host;
      _networkPort = result.port;
      _networkScheme = result.scheme;
      _networkEndpoint = result.endpoint;
      _networkMessage = result.message;
      _latencyMs = result.latencyMs;
    });

    _refreshNetworkConsole(forceRestart: true);
  }

  Color _backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF030B16) : const Color(0xFFF4F7FB);

  Color _panelColor(bool isDark) =>
      isDark ? const Color(0xFF071423) : Colors.white;

  Color _primaryGlow(bool isDark) =>
      isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);

  Color _secondaryGlow(bool isDark) =>
      isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);

  Color _textColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF102030);

  Color _subtleTextColor(bool isDark) =>
      isDark ? const Color(0xFF6FB6FF) : const Color(0xFF376D9A);

  Color _successColor(bool isDark) =>
      isDark ? const Color(0xFF19F6A5) : const Color(0xFF008F5B);

  Color _dangerColor(bool isDark) =>
      isDark ? const Color(0xFFFF5A7A) : const Color(0xFFD81B60);

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
            Container(
              width: AppDesign.topBarIconBoxSize,
              height: AppDesign.topBarIconBoxSize,
              decoration: _glowBox(
                isDark: isDark,
                radius: AppDesign.radiusItem,
              ),
              child: Icon(
                Icons.settings_rounded,
                color: _primaryGlow(isDark),
                size: AppDesign.topBarActionIconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark, String title) {
    return Padding(
      padding: AppDesign.sectionTitlePadding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: _primaryGlow(isDark),
            fontSize: AppDesign.fontSectionTitle,
            letterSpacing: AppDesign.sectionTitleLetterSpacing,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final accentColor = value
        ? (isDark ? const Color(0xFF28DDB3) : const Color(0xFF118C73))
        : _primaryGlow(isDark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: _glowBox(
        isDark: isDark,
        radius: AppDesign.radiusCard,
      ).copyWith(
        border: Border.all(
          color: accentColor.withValues(alpha: value ? 0.48 : 0.24),
          width: 1.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesign.radiusCard),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: AppDesign.itemPadding,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: AppDesign.listLeadingSize,
                  height: AppDesign.listLeadingSize,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: AppDesign.listIconSize,
                  ),
                ),
                const SizedBox(width: AppDesign.gapCompact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            color: _textColor(isDark),
                            fontSize: AppDesign.fontSectionTitle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapXSmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          style: TextStyle(
                            color: _subtleTextColor(isDark),
                            fontSize: AppDesign.fontCaption,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.gapSmall),
                Transform.scale(
                  scale: 0.86,
                  child: Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: accentColor,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFF41506A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdCard(bool isDark) {
    final accentColor = _secondaryGlow(isDark);
    final profile = widget.sensitivityProfile;
    ModelOption? selectedModel;
    for (final model in _availableModels) {
      if (model.id == _selectedModelId) {
        selectedModel = model;
        break;
      }
    }
    final baseThreshold = selectedModel?.threshold ?? 0.5;
    final adjustment = switch (profile) {
      SensitivityProfile.aggressive => -0.25,
      SensitivityProfile.balanced => 0.0,
      SensitivityProfile.passive => 0.25,
    };
    final effectiveThreshold =
        (baseThreshold + adjustment).clamp(0.05, 0.95).toDouble();

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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.equalizer_rounded,
                  color: accentColor,
                  size: AppDesign.topBarActionIconSize,
                ),
              ),
              const SizedBox(width: AppDesign.gapStandard),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensibilidad IA',
                      style: TextStyle(
                        color: _textColor(isDark),
                        fontSize: AppDesign.fontSectionTitle,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      'UMBRAL DE DETECCIÓN',
                      style: TextStyle(
                        color: _subtleTextColor(isDark),
                        fontSize: AppDesign.fontMicro,
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppDesign.cardSubtitleLetterSpacing,
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
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  '${(effectiveThreshold * 100).round()}%',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: AppDesign.fontSectionTitle,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapMedium),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppDesign.gapCompact,
              AppDesign.gapCompact,
              AppDesign.gapCompact,
              AppDesign.gapSmall,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune_rounded, color: accentColor, size: 18),
                    const SizedBox(width: AppDesign.gapSmall),
                    Text(
                      'NIVEL ${profile.label.toUpperCase()}',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: AppDesign.fontCaption,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.gapSmall),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<SensitivityProfile>(
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    segments: const [
                      SensitivityProfile.passive,
                      SensitivityProfile.balanced,
                      SensitivityProfile.aggressive,
                    ]
                        .map(
                          (item) => ButtonSegment<SensitivityProfile>(
                            value: item,
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label.toUpperCase(),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    selected: {profile},
                    onSelectionChanged: (selection) async {
                      await widget.onSensitivityChanged(selection.first);
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? accentColor
                            : _subtleTextColor(isDark),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? accentColor.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(
                          color: accentColor.withValues(alpha: 0.22),
                        ),
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: AppDesign.fontMicro,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: AppDesign.gapXSmall),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.gapSmall),
                Text(
                  '${profile.shortDescription}. Umbral aplicado: '
                  '${(effectiveThreshold * 100).round()}% · Referencia del '
                  'modelo: ${(baseThreshold * 100).round()}%.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: AppDesign.fontMicro,
                    height: AppDesign.bodyLineHeight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final accentColor = _secondaryGlow(isDark);
    return Container(
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesign.radiusCard),
          onTap: onTap,
          child: Padding(
            padding: AppDesign.itemPadding,
            child: Row(
              children: [
                Container(
                  width: AppDesign.listLeadingSize,
                  height: AppDesign.listLeadingSize,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: AppDesign.listIconSize,
                  ),
                ),
                const SizedBox(width: AppDesign.gapCompact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _textColor(isDark),
                          fontSize: AppDesign.fontSectionTitle,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapXSmall),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _subtleTextColor(isDark),
                          fontSize: AppDesign.fontCaption,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.gapSmall),
                Icon(
                  Icons.chevron_right_rounded,
                  color: accentColor,
                  size: AppDesign.topBarActionIconSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ModelOption? get _selectedModel {
    for (final model in _availableModels) {
      if (model.id == _selectedModelId) return model;
    }
    return null;
  }

  Widget _buildModelSelector(bool isDark) {
    final accentColor = _secondaryGlow(isDark);
    final selected = _selectedModel;
    return Container(
      width: double.infinity,
      padding: AppDesign.itemPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppDesign.listLeadingSize,
                height: AppDesign.listLeadingSize,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.psychology_alt_rounded,
                  color: accentColor,
                  size: AppDesign.listIconSize,
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modelo de predicción',
                      style: TextStyle(
                        color: _textColor(isDark),
                        fontSize: AppDesign.fontSectionTitle,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      'Se aplicará en el escáner y en Anita',
                      style: TextStyle(
                        color: _subtleTextColor(isDark),
                        fontSize: AppDesign.fontCaption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapContent),
          if (_modelsLoading)
            LinearProgressIndicator(
              color: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.12),
            )
          else if (_modelsError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _modelsError!,
                    style: TextStyle(
                      color: _dangerColor(isDark),
                      fontSize: AppDesign.fontCaption,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Reintentar',
                  onPressed: _loadModels,
                  icon: Icon(Icons.refresh_rounded, color: accentColor),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesign.gapCompact,
              ),
              decoration: BoxDecoration(
                color: _backgroundColor(isDark).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.32),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedModelId,
                  isExpanded: true,
                  dropdownColor: _panelColor(isDark),
                  icon: Icon(Icons.expand_more_rounded, color: accentColor),
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontSubtitle,
                    fontWeight: FontWeight.w700,
                  ),
                  items: _availableModels
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model.id,
                          child: Text(
                            model.recommended
                                ? '${model.familyLabel} · ${model.displayName} · Recomendado'
                                : '${model.familyLabel} · ${model.displayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null || value == _selectedModelId) return;
                    setState(() => _selectedModelId = value);
                    await _preferencesService.setSelectedModelId(value);
                    if (!mounted) return;
                    final model = _selectedModel;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Modelo activo: ${model?.displayName ?? value}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (selected != null) ...[
            const SizedBox(height: AppDesign.gapCompact),
            Text(
              selected.familyLabel.toUpperCase(),
              style: TextStyle(
                color: accentColor,
                fontSize: AppDesign.fontLabel,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDesign.gapSmall),
            Row(
              children: [
                if (selected.recommended) ...[
                  Icon(Icons.verified_rounded,
                      color: _successColor(isDark), size: 16),
                  const SizedBox(width: AppDesign.gapXSmall),
                  Text(
                    'RECOMENDADO',
                    style: TextStyle(
                      color: _successColor(isDark),
                      fontSize: AppDesign.fontLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                Text(
                  'ACCURACY ${(selected.accuracy * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: AppDesign.fontLabel,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.gapSmall),
            Text(
              selected.description,
              style: TextStyle(
                color: _subtleTextColor(isDark),
                fontSize: AppDesign.fontCaption,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openModelInfo() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => ModelInfoScreen(modelId: _selectedModelId),
      ),
    );
  }

  Widget _buildNetworkCard(bool isDark) {
    final statusColor = _isTestingConnection
        ? const Color(0xFFFFB020)
        : _serverOnline
            ? (isDark ? const Color(0xFF19F6A5) : const Color(0xFF00A86B))
            : const Color(0xFFFF5A7A);

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
                width: AppDesign.listLeadingSize,
                height: AppDesign.listLeadingSize,
                decoration: BoxDecoration(
                  color: _secondaryGlow(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: _secondaryGlow(isDark),
                  size: AppDesign.listIconSize,
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: Text(
                  'CONSOLA DE RED',
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontSectionTitle,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.gapRegular,
                  vertical: AppDesign.gapXSmall,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  _isTestingConnection
                      ? 'TEST'
                      : _serverOnline
                          ? 'ONLINE'
                          : 'IDLE',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: AppDesign.fontMicro,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapStandard),
          RepaintBoundary(
            child: Container(
              width: double.infinity,
              padding: AppDesign.itemPadding,
              decoration: BoxDecoration(
                color: const Color(0xFF020914),
                borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                border: Border.all(
                  color: _primaryGlow(isDark).withValues(alpha: 0.24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _NetworkTerminalDot(color: Color(0xFFFF5A7A)),
                      const SizedBox(width: AppDesign.gapXSmall),
                      const _NetworkTerminalDot(color: Color(0xFFFFB020)),
                      const SizedBox(width: AppDesign.gapXSmall),
                      const _NetworkTerminalDot(color: Color(0xFF19F6A5)),
                      const Spacer(),
                      Text(
                        'SYSTEM://NETWORK',
                        style: TextStyle(
                          color: _primaryGlow(isDark).withValues(alpha: 0.60),
                          fontSize: AppDesign.fontMicro,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDesign.gapCompact),
                  Divider(
                    height: 1,
                    color: _primaryGlow(isDark).withValues(alpha: 0.14),
                  ),
                  const SizedBox(height: AppDesign.gapCompact),
                  ValueListenableBuilder<int>(
                    valueListenable: _networkRenderVersion,
                    builder: (context, _, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_networkVisibleLines.length, (
                          index,
                        ) {
                          final text = _networkVisibleLines[index];
                          final isStatusLine = text.startsWith('> ESTADO:');
                          return Padding(
                            padding: AppDesign.linePadding,
                            child: Text(
                              text.toUpperCase(),
                              style: TextStyle(
                                color: isStatusLine
                                    ? statusColor
                                    : _primaryGlow(true),
                                fontSize: AppDesign.fontBody,
                                fontWeight: isStatusLine
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 0.7,
                                height: AppDesign.bodyLineHeight,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDesign.gapContent),
          Divider(
            color: _primaryGlow(isDark).withValues(alpha: 0.22),
            thickness: 1,
          ),
          const SizedBox(height: AppDesign.gapContent),
          SizedBox(
            width: double.infinity,
            height: AppDesign.standardControlHeight,
            child: ElevatedButton.icon(
              onPressed: _isTestingConnection ? null : _testServerConnection,
              icon: _isTestingConnection
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.dns_rounded, size: AppDesign.listIconSize),
              label: Text(
                _isTestingConnection
                    ? 'PROBANDO CONEXIÓN...'
                    : 'PROBAR CONEXIÓN',
                style: const TextStyle(
                  fontSize: AppDesign.fontSubtitle,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGlow(isDark),
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryGlow(
                  isDark,
                ).withValues(alpha: 0.55),
                disabledForegroundColor: Colors.white,
                padding: AppDesign.buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                ),
                elevation: 8,
                shadowColor: _primaryGlow(isDark).withValues(alpha: 0.30),
              ),
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
        const SizedBox(height: AppDesign.gapLarge),
      ],
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    const selectedIndex = 4;

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

  Widget _buildLoadingView(bool isDark) {
    return Scaffold(
      backgroundColor: _backgroundColor(isDark),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundGrid(isDark)),
          Column(
            children: [
              _buildTopBar(isDark),
              const Expanded(child: Center(child: CircularProgressIndicator())),
              _buildBottomNavigation(isDark),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_preferencesLoaded) {
      return _buildLoadingView(isDark);
    }

    return Scaffold(
      backgroundColor: _backgroundColor(isDark),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundGrid(isDark)),
          Column(
            children: [
              _buildTopBar(isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppDesign.pagePadding,
                  child: AppContentWidth(
                    child: Column(
                      children: [
                        _buildSectionTitle(isDark, 'PREFERENCIAS DE SISTEMA'),
                        _buildSwitchCard(
                          isDark: isDark,
                          icon: Icons.dark_mode_rounded,
                          title: 'Modo Oscuro',
                          subtitle: 'Interfaz de alto contraste',
                          value: isDark,
                          onChanged: (_) async {
                            await widget.onToggleTheme();
                          },
                        ),
                        const SizedBox(height: AppDesign.gapBetweenCards),
                        _buildSwitchCard(
                          isDark: isDark,
                          icon: Icons.vibration_rounded,
                          title: 'Vibración',
                          subtitle: 'Alertas de riesgo',
                          value: _hapticAlerts,
                          onChanged: (value) async {
                            setState(() {
                              _hapticAlerts = value;
                            });

                            await _preferencesService.setHapticAlertsEnabled(
                              value,
                            );
                          },
                        ),
                        const SizedBox(height: AppDesign.gapBetweenCards),
                        _buildSwitchCard(
                          isDark: isDark,
                          icon: Icons.storage_rounded,
                          title: 'Almacenamiento',
                          subtitle: _globalStorageEnabled
                              ? 'Guarda análisis, SHAP y trazas en servidor'
                              : 'Solo memoria temporal; no guarda en servidor',
                          value: _globalStorageEnabled,
                          onChanged: (value) async {
                            await widget.onGlobalStorageChanged(value);
                          },
                        ),
                        const SizedBox(height: AppDesign.gapBetweenSections),
                        _buildSectionTitle(isDark, 'PARÁMETROS DE DETECCIÓN'),
                        _buildThresholdCard(isDark),
                        const SizedBox(height: AppDesign.gapBetweenSections),
                        _buildSectionTitle(
                            isDark, 'MODELO DE INTELIGENCIA ARTIFICIAL'),
                        _buildModelSelector(isDark),
                        const SizedBox(height: AppDesign.gapBetweenCards),
                        _buildNavigationCard(
                          isDark: isDark,
                          icon: Icons.psychology_alt_rounded,
                          title: 'Información del modelo',
                          subtitle: _selectedModel == null
                              ? 'Métricas, matriz de confusión, dataset y variables'
                              : 'Métricas y matriz de ${_selectedModel!.displayName}',
                          onTap: _openModelInfo,
                        ),
                        const SizedBox(height: AppDesign.gapBetweenSections),
                        _buildSectionTitle(isDark, 'DIAGNÓSTICO DE RED'),
                        _buildNetworkCard(isDark),
                        const SizedBox(height: AppDesign.gapCompact),
                        _buildBottomInfo(isDark),
                      ],
                    ),
                  ),
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

class _NetworkTerminalDot extends StatelessWidget {
  const _NetworkTerminalDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
