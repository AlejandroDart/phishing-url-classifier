import 'dart:async';

import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:vibration/vibration.dart';

import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../utils/phishing_utils.dart';
import '../services/preferences_service.dart';

String label = '';
double globalPercentage = 0.0;
Color globalColor = const Color.fromRGBO(149, 196, 190, 1.0);
String globalTitleMessage = '...';
String globalMessage = '...';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
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
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _scanProgress = 0.0;
  Timer? _scanTimer;

  String _detectedURL = '';
  final TextEditingController _urlTextField = TextEditingController();
  final CameraUrlService _cameraUrlService = CameraUrlService();
  final FocusNode _focusNode = FocusNode();

  final PreferencesService _preferencesService = PreferencesService();
  bool _hapticAlertsEnabled = false;

  bool _isPressedIA = false;
  bool _isPressedCamera = false;
  bool _isLoading = false;

  final List<String> _consoleVisibleLines = [];
  List<String> _consoleTargetLines = [];
  Timer? _consoleTypingTimer;
  int _consoleTypingLineIndex = 0;
  int _currentConsolePhase = -1;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _setConsolePhase(0, forceRestart: true);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _consoleTypingTimer?.cancel();
    _urlTextField.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    _focusNode.unfocus();
  }

  void _showSnack(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.removeCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: duration,
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<String> _buildConsoleLinesForPhase(int phase) {
    switch (phase) {
      case 0:
        return [
          '> Sistema en espera...',
          '> Detector listo.',
          '> OCR activo.',
          '> Esperando URL...',
        ];
      case 1:
        return [
          '> Iniciando análisis...',
        ];
      case 2:
        return [
          '> Iniciando análisis...',
          '> Extrayendo features...',
        ];
      case 3:
        return [
          '> Iniciando análisis...',
          '> Extrayendo features...',
          '> Realizando predicción...',
        ];
      case 4:
        return [
          '> Iniciando análisis...',
          '> Extrayendo features...',
          '> Realizando predicción...',
          '> Proceso finalizado.',
        ];
      default:
        return [
          '> Sistema en espera...',
          '> Detector listo.',
          '> OCR activo.',
          '> Esperando URL...',
        ];
    }
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

  void _setConsolePhase(int phase, {bool forceRestart = false}) {
    if (!forceRestart && _currentConsolePhase == phase) {
      return;
    }

    _currentConsolePhase = phase;

    _setConsoleLines(
      _buildConsoleLinesForPhase(phase),
      forceRestart: forceRestart,
    );
  }

  void _setConsoleLines(List<String> newLines, {bool forceRestart = false}) {
    if (_sameLines(_consoleTargetLines, newLines) && !forceRestart) return;

    final oldTarget = List<String>.from(_consoleTargetLines);
    _consoleTargetLines = List<String>.from(newLines);

    final shouldRestart = forceRestart ||
        _consoleVisibleLines.isEmpty ||
        !_isPrefix(oldTarget, newLines);

    if (shouldRestart) {
      _consoleTypingTimer?.cancel();
      _consoleVisibleLines
        ..clear()
        ..add('');
      _consoleTypingLineIndex = 0;

      if (mounted) setState(() {});
      _startConsoleTyping();
      return;
    }

    _consoleTypingTimer?.cancel();

    _consoleTypingLineIndex = _firstIncompleteLineIndex();

    while (_consoleVisibleLines.length <= _consoleTypingLineIndex) {
      _consoleVisibleLines.add('');
    }

    if (mounted) setState(() {});
    _startConsoleTyping();
  }

  int _firstIncompleteLineIndex() {
    for (int i = 0; i < _consoleTargetLines.length; i++) {
      if (i >= _consoleVisibleLines.length) return i;

      final current = _consoleVisibleLines[i];
      final target = _consoleTargetLines[i];

      if (current != target) return i;
    }

    return _consoleTargetLines.length - 1;
  }

  void _startConsoleTyping() {
    _consoleTypingTimer?.cancel();

    _consoleTypingTimer = Timer.periodic(const Duration(milliseconds: 20), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_consoleTypingLineIndex >= _consoleTargetLines.length) {
        timer.cancel();
        return;
      }

      while (_consoleVisibleLines.length <= _consoleTypingLineIndex) {
        _consoleVisibleLines.add('');
      }

      final targetLine = _consoleTargetLines[_consoleTypingLineIndex];
      final currentLine = _consoleVisibleLines[_consoleTypingLineIndex];

      if (currentLine.length < targetLine.length) {
        setState(() {
          _consoleVisibleLines[_consoleTypingLineIndex] = targetLine.substring(
            0,
            currentLine.length + 1,
          );
        });
        return;
      }

      if (_consoleTypingLineIndex < _consoleTargetLines.length - 1) {
        _consoleTypingLineIndex++;

        while (_consoleVisibleLines.length <= _consoleTypingLineIndex) {
          _consoleVisibleLines.add('');
        }
        return;
      }

      timer.cancel();
    });
  }

  void startScanAnimation() {
    _scanProgress = 0.0;
    _setConsolePhase(1, forceRestart: true);

    _scanTimer?.cancel();

    _scanTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_scanProgress >= 0.9) return;

      setState(() {
        _scanProgress = (_scanProgress + 0.015).clamp(0.0, 0.9);
      });

      if (_scanProgress >= 0.75) {
        _setConsolePhase(3);
      } else if (_scanProgress >= 0.35) {
        _setConsolePhase(2);
      }
    });
  }

  void methodPrediction(BuildContext context) async {
    _dismissKeyboard();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trimmedUrl = _urlTextField.text.trim();

    if (trimmedUrl.isEmpty) {
      _scanTimer?.cancel();

      setState(() {
        resetGlobals();
        _isLoading = false;
        _scanProgress = 0.0;
      });

      _setConsolePhase(0);
      _showSnack('Ingresa una URL o utiliza la cámara.');
      return;
    }

    setState(() {
      _isPressedIA = true;
      _isLoading = true;
    });

    startScanAnimation();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isPressedIA = false;
        });
      }
    });

    try {
      final result = await predictPhishing(trimmedUrl);

      _scanTimer?.cancel();

      if (result.containsKey('error')) {
        setState(() {
          label = result['error'];
          globalPercentage = 0.0;
          globalTitleMessage = 'ERROR';
          globalMessage = label;
          globalColor = _dangerColor(isDark);
          _scanProgress = 0.0;
        });

        _setConsolePhase(0);
        _showSnack(label);
      } else {
        setState(() {
          label = result['label'];
          globalPercentage = result['probability'];
          globalColor = getIconColorMessageForPercentage(globalPercentage)[1];
          globalTitleMessage =
              getIconColorMessageForPercentage(globalPercentage)[2];
          globalMessage = getIconColorMessageForPercentage(globalPercentage)[3];
          _scanProgress = 1.0;
        });

        _setConsolePhase(4);
      }
    } catch (e) {
      _scanTimer?.cancel();

      setState(() {
        globalPercentage = 0.0;
        globalTitleMessage = 'ERROR';
        globalMessage = 'No fue posible completar el análisis.';
        globalColor = _dangerColor(isDark);
        _scanProgress = 0.0;
      });

      _setConsolePhase(0);
      _showSnack('Error al analizar la URL: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _dismissKeyboard();
      methodAlert(globalPercentage);
    }
  }

  Future<void> methodAlert(double globalPercentage) async {
    try {
      if (!_hapticAlertsEnabled) return;

      if (globalPercentage > 0.5 && await Vibration.hasVibrator()) {
        Future.delayed(const Duration(milliseconds: 200), () async {
          final hasAmplitude = await Vibration.hasAmplitudeControl();
          final hasCustom = await Vibration.hasCustomVibrationsSupport();

          if (hasAmplitude && hasCustom) {
            Vibration.vibrate(
              pattern: [350, 200, 350],
              intensities: [100, 0, 100],
            );
          } else {
            Vibration.vibrate(duration: 300);
          }
        });
      }
    } catch (e) {
      _showSnack('Error al intentar vibrar: $e');
    }
  }

  void vibrateOnClear() async {
    if (!_hapticAlertsEnabled) return;

    if (await Vibration.hasVibrator()) {
      if (await Vibration.hasAmplitudeControl()) {
        Vibration.vibrate(duration: 100, amplitude: 100);
      } else {
        Vibration.vibrate(duration: 100);
      }
    }
  }

  void methodCamera(BuildContext context) async {
    _dismissKeyboard();

    setState(() {
      _isPressedCamera = true;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isPressedCamera = false;
        });
      }
    });

    final url = await _cameraUrlService.takePictureAndExtractUrl(context);

    if (!mounted) return;
    if (url == null || url == CameraUrlService.cancelledResult) return;

    setState(() {
      _detectedURL = url;
      _urlTextField.text = _detectedURL;
    });
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
            IconButton(
              tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
              onPressed: () async {
                _dismissKeyboard();
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

  Widget _buildScannerSection(bool isDark) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _panelColor(isDark).withValues(alpha: 0.65),
        border: Border.all(
          color: _primaryGlow(isDark).withValues(alpha: 0.55),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryGlow(isDark).withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _primaryGlow(isDark).withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
          ),
          SizedBox(
            width: 250,
            height: 250,
            child: CircularProgressIndicator(
              strokeCap: StrokeCap.round,
              value: _scanProgress,
              strokeWidth: 10,
              color: _primaryGlow(isDark),
              backgroundColor: _primaryGlow(isDark).withValues(alpha: 0.15),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.radar_rounded,
                color: _primaryGlow(isDark),
                size: 88,
              ),
              const SizedBox(height: 18),
              Text(
                _isLoading ? 'ANALIZANDO OBJETIVO...' : 'ESCANEANDO ENTORNO...',
                style: TextStyle(
                  color: _primaryGlow(isDark),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'URL A ESCANEAR:',
          style: TextStyle(
            color: _primaryGlow(isDark),
            fontSize: 16,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: _glowBox(isDark: isDark, radius: 18),
          child: TextField(
            controller: _urlTextField,
            focusNode: _focusNode,
            style: TextStyle(
              color: _textColor(isDark),
              fontSize: 14,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              hintText: 'https://google.xyz/',
              hintStyle: TextStyle(
                color: _subtleTextColor(isDark).withValues(alpha: 0.55),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 22,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Limpiar',
                    onPressed: () {
                      _dismissKeyboard();

                      final alreadyClean = _urlTextField.text.trim().isEmpty &&
                          !_isLoading &&
                          _scanProgress == 0.0 &&
                          globalTitleMessage == '...';

                      _scanTimer?.cancel();

                      setState(() {
                        _urlTextField.text = '';
                        resetGlobals();
                        _scanProgress = 0.0;
                        _isLoading = false;
                      });

                      if (!alreadyClean) {
                        _setConsolePhase(0);
                        _showSnack('Campos restablecidos.');
                        vibrateOnClear();
                      }
                    },
                    icon: Icon(
                      Icons.cleaning_services_rounded,
                      color: _secondaryGlow(isDark),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: _primaryGlow(isDark).withValues(alpha: 0.25),
                  ),
                  IconButton(
                    tooltip: 'Analizar URL',
                    onPressed: () => methodPrediction(context),
                    icon: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      color: _primaryGlow(isDark),
                    ),
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => methodPrediction(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            isDark: isDark,
            icon: Icons.camera_alt_rounded,
            label: 'ESCANEO VISUAL',
            isPressed: _isPressedCamera,
            onTap: () => methodCamera(context),
            primaryColor: _primaryGlow(isDark),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionCard(
            isDark: isDark,
            icon: Icons.memory_rounded,
            label: 'ANÁLISIS PROFUNDO',
            isPressed: _isPressedIA,
            onTap: () => methodPrediction(context),
            primaryColor: _secondaryGlow(isDark),
          ),
        ),
      ],
    );
  }

  Color _resolveConsoleLineColor(String text, bool isDark) {
    final lower = text.toLowerCase();

    if (lower.contains('advertencia') || lower.contains('error')) {
      return _dangerColor(isDark);
    }

    if (lower.contains('seguro') || lower.contains('validado')) {
      return const Color(0xFF19F6A5);
    }

    if (lower.contains('finalizado') || lower.contains('completado')) {
      return _secondaryGlow(isDark);
    }

    return _primaryGlow(isDark);
  }

  Widget _buildConsolePanel(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _glowBox(isDark: isDark, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SALIDA DE CONSOLA',
            style: TextStyle(
              color: _textColor(isDark),
              fontSize: 16,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_consoleVisibleLines.length, (index) {
            final text = _consoleVisibleLines[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                text,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  color: _resolveConsoleLineColor(text, isDark),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          Divider(
            color: _primaryGlow(isDark).withValues(alpha: 0.22),
            thickness: 1,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PROBABILIDAD DE PHISHING:',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primaryGlow(isDark),
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${(globalPercentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: globalPercentage >= 0.5
                        ? _dangerColor(isDark)
                        : _secondaryGlow(isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LinearPercentIndicator(
              lineHeight: 12.0,
              percent: globalPercentage.clamp(0.0, 1.0),
              padding: EdgeInsets.zero,
              animation: true,
              animationDuration: 700,
              linearGradient: const LinearGradient(
                colors: [
                  Color(0xFF19F6A5),
                  Color(0xFFF4D03F),
                  Color(0xFFFF8C42),
                  Color(0xFFFF2D78),
                ],
              ),
              backgroundColor: _primaryGlow(isDark).withValues(alpha: 0.12),
              barRadius: const Radius.circular(24),
            ),
          ),
          const SizedBox(height: 22),
          _buildStatusCard(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _backgroundColor(isDark).withValues(alpha: isDark ? 0.65 : 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: globalColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: globalColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              getIconColorMessageForPercentage(globalPercentage)[0],
              color: globalColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  globalTitleMessage,
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  globalMessage,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    color: _subtleTextColor(isDark),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
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
                    _dismissKeyboard();
                    widget.onNavigate(0);
                  },
                  icon: Icon(
                    Icons.shield_rounded,
                    color: _primaryGlow(isDark),
                    size: 28,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                _dismissKeyboard();
                widget.onNavigate(1);
              },
              icon: Icon(
                Icons.bar_chart_rounded,
                color: _primaryGlow(isDark),
                size: 28,
              ),
            ),
            IconButton(
              onPressed: () {
                _dismissKeyboard();
              },
              icon: Icon(
                Icons.history_rounded,
                color: _primaryGlow(isDark),
                size: 28,
              ),
            ),
            IconButton(
              onPressed: () {
                _dismissKeyboard();
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: !isLandscape,
        backgroundColor: _backgroundColor(isDark),
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackgroundGrid(isDark)),
            Column(
              children: [
                _buildTopBar(isDark),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                    child: Column(
                      children: [
                        _buildScannerSection(isDark),
                        const SizedBox(height: 26),
                        _buildUrlInput(isDark),
                        const SizedBox(height: 22),
                        _buildActionButtons(isDark),
                        const SizedBox(height: 22),
                        _buildConsolePanel(isDark),
                        _buildBottomInfo(isDark),
                      ],
                    ),
                  ),
                ),
                _buildBottomNavigation(isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final hapticEnabled = await _preferencesService.getHapticAlertsEnabled();

    if (!mounted) return;

    setState(() {
      _hapticAlertsEnabled = hapticEnabled;
    });
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.isPressed,
    required this.onTap,
    required this.primaryColor,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final bool isPressed;
  final VoidCallback onTap;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: isPressed ? 1.04 : 1.0),
      duration: const Duration(milliseconds: 180),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF071423).withValues(alpha: 0.82)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.42),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.12),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: primaryColor, size: 42),
                  const SizedBox(height: 18),
                  Text(
                    label,
                    style: TextStyle(
                      color: primaryColor,
                      letterSpacing: 1,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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