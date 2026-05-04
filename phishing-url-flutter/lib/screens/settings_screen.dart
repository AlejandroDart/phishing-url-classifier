import 'dart:async';

import 'package:flutter/material.dart';

import '../services/preferences_service.dart';
import '../services/network_diagnostic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _preferencesLoaded = false;
  bool _hapticAlerts = false;
  double _detectionThreshold = 0.75;

  final PreferencesService _preferencesService = PreferencesService();
  final NetworkDiagnosticService _networkDiagnosticService =
      const NetworkDiagnosticService();

  bool _isTestingConnection = false;
  bool _serverOnline = false;
  String _networkStatus = 'SIN PROBAR';
  String _networkHost = '-';
  String _networkPort = '-';
  String _networkScheme = '-';
  String _networkEndpoint = '-';
  String _networkMessage = 'Presiona el botón para probar conexión.';
  int? _latencyMs;

  final List<String> _networkVisibleLines = [];
  List<String> _networkTargetLines = [];
  Timer? _networkTypingTimer;
  int _networkTypingLineIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _networkTypingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _loadPreferences();
    _refreshNetworkConsole(forceRestart: true);
  }

  Future<void> _loadPreferences() async {
    final hapticEnabled = await _preferencesService.getHapticAlertsEnabled();

    if (!mounted) return;

    setState(() {
      _hapticAlerts = hapticEnabled;
      _preferencesLoaded = true;
    });
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

      if (mounted) setState(() {});
      _startNetworkTyping();
      return;
    }

    _networkTypingTimer?.cancel();
    _networkTypingLineIndex = _firstIncompleteNetworkLineIndex();

    while (_networkVisibleLines.length <= _networkTypingLineIndex) {
      _networkVisibleLines.add('');
    }

    if (mounted) setState(() {});
    _startNetworkTyping();
  }

  void _startNetworkTyping() {
    _networkTypingTimer?.cancel();

    _networkTypingTimer = Timer.periodic(
      const Duration(milliseconds: 18),
      (timer) {
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
          setState(() {
            _networkVisibleLines[_networkTypingLineIndex] = targetLine.substring(
              0,
              currentLine.length + 1,
            );
          });
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
      },
    );
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
            Container(
              width: 52,
              height: 52,
              decoration: _glowBox(isDark: isDark, radius: 14),
              child: Icon(
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

  Widget _buildSectionTitle(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: _primaryGlow(isDark),
            fontSize: 16,
            letterSpacing: 3,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primaryGlow(isDark).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: _primaryGlow(isDark),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _primaryGlow(isDark),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF41506A),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _primaryGlow(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.equalizer_rounded,
                  color: _primaryGlow(isDark),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Umbral de Sensibilidad',
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(_detectionThreshold * 100).round()}%',
                style: TextStyle(
                  color: _primaryGlow(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: _primaryGlow(isDark),
              inactiveTrackColor: _primaryGlow(isDark).withValues(alpha: 0.20),
              thumbColor: _primaryGlow(isDark),
              overlayColor: _primaryGlow(isDark).withValues(alpha: 0.16),
            ),
            child: Slider(
              value: _detectionThreshold,
              min: 0.20,
              max: 0.95,
              divisions: 15,
              onChanged: (value) {
                setState(() {
                  _detectionThreshold = value;
                });
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PASIVO',
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'EQUILIBRADO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'AGRESIVO',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(bool isDark) {
    final statusColor = _isTestingConnection
        ? const Color(0xFFFFB020)
        : _serverOnline
            ? const Color(0xFF19F6A5)
            : const Color(0xFFFF5A7A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF020814),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _primaryGlow(isDark).withValues(alpha: 0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DIAGNÓSTICO DE RED',
              style: TextStyle(
                color: _primaryGlow(isDark),
                fontSize: 14,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(_networkVisibleLines.length, (index) {
              final text = _networkVisibleLines[index];
              final bool isStatusLine = text.startsWith('> ESTADO:');

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isStatusLine ? statusColor : _subtleTextColor(isDark),
                    fontSize: isStatusLine ? 14 : 13.5,
                    fontWeight:
                        isStatusLine ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.9,
                    height: 1.3,
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 58,
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
                    : const Icon(Icons.dns_rounded, size: 22),
                label: Text(
                  _isTestingConnection
                      ? 'PROBANDO CONEXIÓN...'
                      : 'PROBAR CONEXIÓN',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGlow(isDark),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _primaryGlow(isDark).withValues(alpha: 0.55),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: _primaryGlow(isDark).withValues(alpha: 0.30),
                ),
              ),
            ),
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
            IconButton(
              onPressed: () {
                widget.onNavigate(1);
              },
              icon: Icon(
                Icons.bar_chart_rounded,
                color: _primaryGlow(isDark),
                size: 28,
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
                    widget.onNavigate(2);
                  },
                  icon: Icon(
                    Icons.settings_rounded,
                    color: _primaryGlow(isDark),
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
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
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
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
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: Column(
                    children: [
                      _buildSectionTitle(isDark, 'PREFERENCIAS DE SISTEMA'),
                      _buildSwitchCard(
                        isDark: isDark,
                        icon: Icons.dark_mode_rounded,
                        title: 'Modo Oscuro',
                        subtitle: 'Activar interfaz de alto contraste',
                        value: isDark,
                        onChanged: (_) async {
                          await widget.onToggleTheme();
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildSwitchCard(
                        isDark: isDark,
                        icon: Icons.vibration_rounded,
                        title: 'Alertas Hápticas',
                        subtitle: 'Vibración en detecciones críticas',
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
                      const SizedBox(height: 28),
                      _buildSectionTitle(isDark, 'PARÁMETROS DE DETECCIÓN'),
                      _buildThresholdCard(isDark),
                      const SizedBox(height: 28),
                      _buildSectionTitle(isDark, 'DIAGNÓSTICO DE RED'),
                      _buildNetworkCard(isDark),
                      const SizedBox(height: 28),
                    ],
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