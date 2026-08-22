import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/app_content_width.dart';
import '../widgets/robot_rain_overlay.dart';
import 'package:vibration/vibration.dart';

import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../models/local_prediction.dart';
import '../services/local_prediction_repository.dart';
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
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  double _scanProgress = 0.0;
  final ValueNotifier<double> _scanProgressRender = ValueNotifier<double>(0);
  Timer? _scanTimer;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _urlInputSectionKey = GlobalKey();

  bool _userMovedScroll = false;
  bool _autoScrollEnabledForCurrentScan = true;
  final GlobalKey _consoleSectionKey = GlobalKey();

  String _detectedURL = '';
  final TextEditingController _urlTextField = TextEditingController();
  final TextEditingController _chatbotTextController = TextEditingController();
  final CameraUrlService _cameraUrlService = CameraUrlService();
  final FocusNode _focusNode = FocusNode();

  final PreferencesService _preferencesService = PreferencesService();
  final LocalPredictionRepository _localPredictionRepository =
      LocalPredictionRepository();
  bool _hapticAlertsEnabled = false;

  bool _isPressedIA = false;
  bool _isPressedCamera = false;
  bool _isLoading = false;
  Offset? _chatbotPosition;

  final List<String> _consoleVisibleLines = [];
  final ValueNotifier<int> _consoleRenderVersion = ValueNotifier<int>(0);
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
    _scanProgressRender.dispose();
    _consoleTypingTimer?.cancel();
    _consoleRenderVersion.dispose();
    _urlTextField.dispose();
    _chatbotTextController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void setSharedText(String sharedText) {
    final match = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(sharedText);
    if (match == null) return;

    final sharedUrl =
        match.group(0)!.replaceFirst(RegExp(r'[\]\[(){}<>,.;!?]+$'), '');

    FocusManager.instance.primaryFocus?.unfocus();
    _focusNode.unfocus();

    setState(() {
      _detectedURL = sharedUrl;
      _urlTextField.value = TextEditingValue(
        text: sharedUrl,
        selection: const TextSelection.collapsed(offset: 0),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;

      FocusManager.instance.primaryFocus?.unfocus();
      _focusNode.unfocus();

      final inputContext = _urlInputSectionKey.currentContext;
      if (inputContext == null || !inputContext.mounted) return;
      await Scrollable.ensureVisible(
        inputContext,
        alignment: 0.06,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollToConsoleIfAllowed() {
    if (!_autoScrollEnabledForCurrentScan || _userMovedScroll) return;
    if (!_scrollController.hasClients) return;

    final context = _consoleSectionKey.currentContext;
    if (context == null) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final boxOffset = renderObject.localToGlobal(Offset.zero);

    final targetOffset = (_scrollController.offset + boxOffset.dy + 20).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOutCubic,
    );
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
        content: Text(message, textAlign: TextAlign.center),
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
        return ['> Iniciando análisis...'];
      case 2:
        return ['> Iniciando análisis...', '> Extrayendo features...'];
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
          '> Interpretando IA (SHAP)...',
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

      _consoleRenderVersion.value++;
      _startConsoleTyping();
      return;
    }

    _consoleTypingTimer?.cancel();

    _consoleTypingLineIndex = _firstIncompleteLineIndex();

    while (_consoleVisibleLines.length <= _consoleTypingLineIndex) {
      _consoleVisibleLines.add('');
    }

    _consoleRenderVersion.value++;
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

    _consoleTypingTimer = Timer.periodic(const Duration(milliseconds: 32), (
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
        final nextLength = math.min(currentLine.length + 2, targetLine.length);
        _consoleVisibleLines[_consoleTypingLineIndex] = targetLine.substring(
          0,
          nextLength,
        );
        _consoleRenderVersion.value++;
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
    _scanProgressRender.value = 0.0;
    _setConsolePhase(1, forceRestart: true);

    _scanTimer?.cancel();

    _scanTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_scanProgress >= 0.9) return;

      _scanProgress = (_scanProgress + 0.015).clamp(0.0, 0.9);
      _scanProgressRender.value = _scanProgress;

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
      _scanProgressRender.value = 0.0;

      _setConsolePhase(0);
      _showSnack('Ingresa una URL o utiliza la cámara.');
      return;
    }

    setState(() {
      _isPressedIA = true;
      _isLoading = true;
      _userMovedScroll = false;
      _autoScrollEnabledForCurrentScan = true;
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
        _scanProgressRender.value = 0.0;

        _setConsolePhase(0);
        _showSnack(label);
      } else {
        setState(() {
          label = result['label'];
          globalPercentage = result['probability'];
          final isPhishing = label == 'phishing';
          final profile =
              (result['sensitivity_profile'] ?? 'balanced').toString();
          final profileLabel = switch (profile) {
            'aggressive' => 'Agresivo',
            'passive' => 'Pasivo',
            _ => 'Equilibrado',
          };
          final threshold =
              ((result['effective_threshold'] ?? 0.5) as num).toDouble();
          globalColor = isPhishing
              ? _dangerColor(isDark)
              : const Color.fromRGBO(67, 212, 165, 1.0);
          globalTitleMessage =
              isPhishing ? 'PHISHING DETECTADO' : 'NO PHISHING';
          globalMessage =
              'Probabilidad ${(globalPercentage * 100).toStringAsFixed(1)}% · '
              'Perfil $profileLabel · Umbral ${(threshold * 100).toStringAsFixed(1)}%.';
          _scanProgress = 1.0;
        });
        _scanProgressRender.value = 1.0;

        _setConsolePhase(4);

        try {
          await _localPredictionRepository.insertPrediction(
            LocalPrediction(
              url: trimmedUrl,
              label: label,
              probability: globalPercentage,
              explanation: jsonEncode(result['explanation']),
              modelId: (result['model_id'] ?? 'random_forest').toString(),
              modelName:
                  (result['model_name'] ?? 'Random Forest Top 25').toString(),
              sensitivityProfile:
                  (result['sensitivity_profile'] ?? 'balanced').toString(),
              baseThreshold:
                  ((result['base_threshold'] ?? 0.5) as num).toDouble(),
              effectiveThreshold:
                  ((result['effective_threshold'] ?? 0.5) as num).toDouble(),
              createdAt: DateTime.now(),
            ),
          );
        } catch (_) {
          _showSnack(
            'El an\u00e1lisis termin\u00f3, pero no pudo guardarse en el historial local.',
          );
        }

        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          _scrollToConsoleIfAllowed();
        });
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
      _scanProgressRender.value = 0.0;

      _setConsolePhase(0);
      _showSnack('Error al analizar la URL: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _dismissKeyboard();
      methodAlert(label == 'phishing');
    }
  }

  Future<void> methodAlert(bool isPhishing) async {
    try {
      if (!_hapticAlertsEnabled) return;

      if (isPhishing && await Vibration.hasVibrator()) {
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

  void _showChatbotPanel(bool isDark) {
    _dismissKeyboard();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String? statusMessage;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                margin: AppDesign.detailsSheetMargin,
                padding: AppDesign.detailsSheetPadding,
                decoration: BoxDecoration(
                  color: _panelColor(isDark),
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                  border: Border.all(
                    color: _secondaryGlow(isDark).withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: AppDesign.topBarIconBoxSize,
                            height: AppDesign.topBarIconBoxSize,
                            decoration: BoxDecoration(
                              color: _secondaryGlow(
                                isDark,
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                AppDesign.radiusItem,
                              ),
                            ),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: _secondaryGlow(isDark),
                              size: AppDesign.topBarActionIconSize,
                            ),
                          ),
                          const SizedBox(width: AppDesign.gapItem),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ASISTENTE VIRTUAL',
                                  style: TextStyle(
                                    color: _primaryGlow(isDark),
                                    fontSize: AppDesign.fontSectionTitle,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: AppDesign.gapTiny),
                                Text(
                                  'Chatbot de seguridad en preparación',
                                  style: TextStyle(
                                    color: _subtleTextColor(isDark),
                                    fontSize: AppDesign.fontLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: _primaryGlow(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesign.gapContent),
                      Text(
                        'Escribe tu consulta de seguridad:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textColor(isDark),
                          fontSize: AppDesign.fontBody,
                          height: AppDesign.bodyLineHeight,
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapStandard),
                      TextField(
                        controller: _chatbotTextController,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          final message = _chatbotTextController.text.trim();
                          if (message.isEmpty) return;
                          _chatbotTextController.clear();
                          setModalState(() {
                            statusMessage =
                                'Mensaje recibido. El asistente se conectará próximamente.';
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          suffixIcon: IconButton(
                            tooltip: 'Enviar',
                            onPressed: () {
                              final message =
                                  _chatbotTextController.text.trim();
                              if (message.isEmpty) return;
                              _chatbotTextController.clear();
                              setModalState(() {
                                statusMessage =
                                    'Mensaje recibido. El asistente se conectará próximamente.';
                              });
                            },
                            icon: Icon(
                              Icons.send_rounded,
                              color: _secondaryGlow(isDark),
                            ),
                          ),
                        ),
                      ),
                      if (statusMessage != null) ...[
                        const SizedBox(height: AppDesign.gapCompact),
                        Text(
                          statusMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _subtleTextColor(isDark),
                            fontSize: AppDesign.fontCaption,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDesign.gapStandard),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildLegacyDraggableChatbot(bool isDark, BoxConstraints constraints) {
    final defaultPosition = Offset(
      constraints.maxWidth -
          AppDesign.chatbotButtonSize -
          AppDesign.chatbotScreenMargin,
      constraints.maxHeight -
          AppDesign.chatbotButtonSize -
          AppDesign.chatbotBottomClearance,
    );
    final currentPosition = _chatbotPosition ?? defaultPosition;
    final double maxLeft = math
        .max(
          AppDesign.chatbotScreenMargin,
          constraints.maxWidth -
              AppDesign.chatbotButtonSize -
              AppDesign.chatbotScreenMargin,
        )
        .toDouble();
    final double maxTop = math
        .max(
          120.0,
          constraints.maxHeight -
              AppDesign.chatbotButtonSize -
              AppDesign.chatbotBottomClearance,
        )
        .toDouble();
    final safePosition = Offset(
      currentPosition.dx
          .clamp(AppDesign.chatbotScreenMargin, maxLeft)
          .toDouble(),
      currentPosition.dy.clamp(120.0, maxTop).toDouble(),
    );

    return Positioned(
      left: safePosition.dx,
      top: safePosition.dy,
      child: Semantics(
        button: true,
        label: 'Abrir asistente virtual',
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _chatbotPosition = Offset(
                (safePosition.dx + details.delta.dx)
                    .clamp(AppDesign.chatbotScreenMargin, maxLeft)
                    .toDouble(),
                (safePosition.dy + details.delta.dy)
                    .clamp(120.0, maxTop)
                    .toDouble(),
              );
            });
          },
          onLongPress: () {
            setState(() {
              _chatbotPosition = null;
            });
          },
          onTap: () => _showChatbotPanel(isDark),
          child: Container(
            width: AppDesign.chatbotButtonSize,
            height: AppDesign.chatbotButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _panelColor(isDark),
              border: Border.all(
                color: _secondaryGlow(isDark).withValues(alpha: 0.75),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _secondaryGlow(isDark).withValues(alpha: 0.32),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: _secondaryGlow(isDark),
              size: AppDesign.sectionIconSize,
            ),
          ),
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
                _dismissKeyboard();
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

  Widget _buildScannerSection(bool isDark) {
    return ValueListenableBuilder<double>(
      valueListenable: _scanProgressRender,
      builder: (context, progress, child) {
        final activeColor =
            _isLoading ? _secondaryGlow(isDark) : _primaryGlow(isDark);

        return RepaintBoundary(
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(280),
                  painter: _ScannerDialPainter(
                    progress: progress,
                    isActive: _isLoading,
                    primaryColor: _primaryGlow(isDark),
                    secondaryColor: _secondaryGlow(isDark),
                    panelColor: _panelColor(isDark),
                  ),
                ),
                Container(
                  width: 164,
                  height: 164,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _panelColor(isDark),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.38),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.16),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusControl,
                          ),
                          border: Border.all(
                            color: activeColor.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Icon(
                          _isLoading
                              ? Icons.travel_explore_rounded
                              : Icons.radar_rounded,
                          color: activeColor,
                          size: AppDesign.actionIconSize,
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapCompact),
                      Text(
                        _isLoading ? 'ANALIZANDO' : 'SISTEMA LISTO',
                        style: TextStyle(
                          color: activeColor,
                          fontSize: AppDesign.fontLabel,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapTiny),
                      Text(
                        _isLoading
                            ? '${(progress * 100).round()}% COMPLETADO'
                            : 'ESCANEO URL',
                        style: TextStyle(
                          color: _subtleTextColor(isDark),
                          fontSize: AppDesign.fontMicro,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUrlInput(bool isDark) {
    return Column(
      key: _urlInputSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppDesign.listLeadingSize,
              height: AppDesign.listLeadingSize,
              decoration: BoxDecoration(
                color: _primaryGlow(isDark).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
              ),
              child: Icon(
                Icons.link_rounded,
                color: _primaryGlow(isDark),
                size: AppDesign.listIconSize,
              ),
            ),
            const SizedBox(width: AppDesign.gapCompact),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL A ESCANEAR',
                    style: TextStyle(
                      color: _primaryGlow(isDark),
                      fontSize: AppDesign.fontSectionTitle,
                      letterSpacing: AppDesign.cardTitleLetterSpacing,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppDesign.gapTiny),
                  Text(
                    'PEGA O CAPTURA UN LINK FÁCIL',
                    style: TextStyle(
                      color: _subtleTextColor(isDark),
                      fontSize: AppDesign.fontMicro,
                      letterSpacing: AppDesign.cardSubtitleLetterSpacing,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesign.gapRegular,
                vertical: AppDesign.gapXSmall,
              ),
              decoration: BoxDecoration(
                color: _secondaryGlow(isDark).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                border: Border.all(
                  color: _secondaryGlow(isDark).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'URL',
                style: TextStyle(
                  color: _secondaryGlow(isDark),
                  fontSize: AppDesign.fontMicro,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesign.gapItem),
        Container(
          decoration: BoxDecoration(
            color: _panelColor(isDark),
            borderRadius: BorderRadius.circular(AppDesign.radiusControl),
            border: Border.all(
              color: _primaryGlow(isDark).withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryGlow(isDark).withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: _urlTextField,
            focusNode: _focusNode,
            style: TextStyle(
              color: _textColor(isDark),
              fontSize: AppDesign.fontBody,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              filled: false,
              hintText: 'https://google.xyz/',
              hintStyle: TextStyle(
                color: _subtleTextColor(isDark).withValues(alpha: 0.55),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: AppDesign.controlPadding,
              prefixIcon: Icon(
                Icons.language_rounded,
                color: _primaryGlow(isDark),
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
                      _scanProgressRender.value = 0.0;

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
            subtitle: 'CAPTURAR URL',
            isPressed: _isPressedCamera,
            onTap: () => methodCamera(context),
            primaryColor: _primaryGlow(isDark),
          ),
        ),
        const SizedBox(width: AppDesign.gapStandard),
        Expanded(
          child: _ActionCard(
            isDark: isDark,
            icon: Icons.memory_rounded,
            label: 'ANÁLISIS IA',
            subtitle: 'EJECUTAR MODELO',
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
    final hasResult = globalTitleMessage != '...' || globalPercentage > 0;
    final riskColor = hasResult ? globalColor : _primaryGlow(isDark);
    final riskLevel = !hasResult
        ? 'SIN DATOS'
        : globalPercentage >= 0.75
            ? 'CRÍTICO'
            : globalPercentage >= 0.40
                ? 'PRECAUCIÓN'
                : 'BAJO';

    return Container(
      key: _consoleSectionKey,
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
                  Icons.terminal_rounded,
                  color: _secondaryGlow(isDark),
                  size: AppDesign.listIconSize,
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: Text(
                  'SALIDA',
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontSectionTitle,
                    letterSpacing: AppDesign.cardTitleLetterSpacing,
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
                  color: _secondaryGlow(isDark).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  border: Border.all(
                    color: _secondaryGlow(isDark).withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  _isLoading ? 'LIVE' : 'READY',
                  style: TextStyle(
                    color: _secondaryGlow(isDark),
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
                      const _TerminalDot(color: Color(0xFFFF5A7A)),
                      const SizedBox(width: AppDesign.gapXSmall),
                      const _TerminalDot(color: Color(0xFFFFB020)),
                      const SizedBox(width: AppDesign.gapXSmall),
                      const _TerminalDot(color: Color(0xFF19F6A5)),
                      const Spacer(),
                      Text(
                        'SYSTEM://SCAN',
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
                    valueListenable: _consoleRenderVersion,
                    builder: (context, _, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_consoleVisibleLines.length, (
                          index,
                        ) {
                          final text = _consoleVisibleLines[index];
                          return Padding(
                            padding: AppDesign.linePadding,
                            child: Text(
                              text.toUpperCase(),
                              style: TextStyle(
                                color: _resolveConsoleLineColor(text, true),
                                fontSize: AppDesign.fontBody,
                                letterSpacing: 0.25,
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
          Container(
            width: double.infinity,
            padding: AppDesign.itemPadding,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(color: riskColor.withValues(alpha: 0.24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: AppDesign.listLeadingSize,
                      height: AppDesign.listLeadingSize,
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusSmall,
                        ),
                      ),
                      child: Icon(
                        Icons.monitor_heart_outlined,
                        color: riskColor,
                        size: AppDesign.listIconSize,
                      ),
                    ),
                    const SizedBox(width: AppDesign.gapCompact),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RIESGO',
                            style: TextStyle(
                              color: _textColor(isDark),
                              fontSize: AppDesign.fontSubtitle,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: AppDesign.gapTiny),
                          Text(
                            riskLevel,
                            style: TextStyle(
                              color: riskColor,
                              fontSize: AppDesign.fontCaption,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(globalPercentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: riskColor,
                        fontSize: AppDesign.fontMetric,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.gapStandard),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: globalPercentage.clamp(0.0, 1.0),
                    backgroundColor: _primaryGlow(
                      isDark,
                    ).withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  ),
                ),
                const SizedBox(height: AppDesign.gapSmall),
                Row(
                  children: [
                    Text(
                      'SEGURO',
                      style: TextStyle(
                        color: _successColor(isDark),
                        fontSize: AppDesign.fontMicro,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'PRECAUCIÓN',
                      style: TextStyle(
                        color: Color(0xFFFFB020),
                        fontSize: AppDesign.fontMicro,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'CRÍTICO',
                      style: TextStyle(
                        color: _dangerColor(isDark),
                        fontSize: AppDesign.fontMicro,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.gapLarge),
          _buildStatusCard(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final hasResult = globalTitleMessage != '...' || globalPercentage > 0;
    final statusColor = hasResult ? globalColor : _primaryGlow(isDark);
    final title = hasResult ? globalTitleMessage : 'SIN ANÁLISIS';
    final message = hasResult ? globalMessage : '';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: isDark ? 0.16 : 0.10),
            _backgroundColor(isDark).withValues(alpha: isDark ? 0.72 : 0.58),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDesign.radiusControl),
        border: Border.all(color: statusColor.withValues(alpha: 0.36)),
      ),
      child: Row(
        children: [
          Container(width: 5, height: 112, color: statusColor),
          Expanded(
            child: Padding(
              padding: AppDesign.itemPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppDesign.topBarIconBoxSize,
                    height: AppDesign.topBarIconBoxSize,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                    ),
                    child: Icon(
                      hasResult
                          ? getIconColorMessageForPercentage(
                              globalPercentage,
                            )[0]
                          : Icons.shield_outlined,
                      color: statusColor,
                      size: AppDesign.sectionIconSize,
                    ),
                  ),
                  const SizedBox(width: AppDesign.gapItem),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESULTADO DEL ANÁLISIS',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: AppDesign.fontMicro,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapXSmall),
                        Text(
                          title,
                          style: TextStyle(
                            color: _textColor(isDark),
                            fontSize: AppDesign.fontSectionTitle,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: AppDesign.gapSmall),
                          Text(
                            message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _subtleTextColor(isDark),
                              fontSize: AppDesign.fontBody,
                              height: AppDesign.bodyLineHeight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
    const selectedIndex = 0;

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
          onPressed: () {
            _dismissKeyboard();
            widget.onNavigate(index);
          },
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: !isLandscape,
        backgroundColor: _backgroundColor(isDark),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(child: _buildBackgroundGrid(isDark)),
                Column(
                  children: [
                    _buildTopBar(isDark),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is UserScrollNotification ||
                              notification is ScrollUpdateNotification) {
                            if (_isLoading) {
                              _userMovedScroll = true;
                              _autoScrollEnabledForCurrentScan = false;
                            }
                          }

                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: AppDesign.pagePadding,
                          child: AppContentWidth(
                            child: Column(
                              children: [
                                _buildScannerSection(isDark),
                                const SizedBox(height: AppDesign.gapLarge),
                                _buildUrlInput(isDark),
                                const SizedBox(height: AppDesign.gapLarge),
                                _buildActionButtons(isDark),
                                const SizedBox(height: AppDesign.gapLarge),
                                _buildConsolePanel(isDark),
                                _buildBottomInfo(isDark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildBottomNavigation(isDark),
                  ],
                ),
              ],
            );
          },
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

class _ScannerDialPainter extends CustomPainter {
  const _ScannerDialPainter({
    required this.progress,
    required this.isActive,
    required this.primaryColor,
    required this.secondaryColor,
    required this.panelColor,
  });

  final double progress;
  final bool isActive;
  final Color primaryColor;
  final Color secondaryColor;
  final Color panelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final activeColor = isActive ? secondaryColor : primaryColor;
    final outerRadius = size.shortestSide / 2 - 5;

    canvas.drawCircle(
      center,
      outerRadius,
      Paint()..color = panelColor.withValues(alpha: 0.72),
    );

    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 118, ringPaint);
    canvas.drawCircle(center, 96, ringPaint);

    final crosshairPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - 116, center.dy),
      Offset(center.dx + 116, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 116),
      Offset(center.dx, center.dy + 116),
      crosshairPaint,
    );

    for (int index = 0; index < 48; index++) {
      final angle = -math.pi / 2 + index * math.pi * 2 / 48;
      final isMajor = index % 4 == 0;
      final innerRadius = isMajor ? 124.0 : 129.0;
      final tickPaint = Paint()
        ..color = isMajor
            ? secondaryColor.withValues(alpha: 0.82)
            : primaryColor.withValues(alpha: 0.28)
        ..strokeWidth = isMajor ? 2.2 : 1;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerRadius,
          center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        ),
        tickPaint,
      );
    }

    final baseArcPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 112),
      -math.pi / 2,
      math.pi * 2,
      false,
      baseArcPaint,
    );

    final visibleProgress =
        isActive ? progress.clamp(0.0, 1.0).toDouble() : 0.0;
    final progressPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 112),
      -math.pi / 2,
      math.pi * 2 * visibleProgress,
      false,
      progressPaint,
    );

    if (isActive) {
      final sweepAngle = -math.pi / 2 + math.pi * 2 * progress;
      final sweepPaint = Paint()
        ..color = secondaryColor.withValues(alpha: 0.34)
        ..strokeWidth = 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(sweepAngle) * 108,
          center.dy + math.sin(sweepAngle) * 108,
        ),
        sweepPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isActive != isActive ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.panelColor != panelColor;
}

class _TerminalDot extends StatelessWidget {
  const _TerminalDot({required this.color});

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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isPressed,
    required this.onTap,
    required this.primaryColor,
  });

  final bool isDark;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isPressed;
  final VoidCallback onTap;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: isPressed ? 0.97 : 1.0),
      duration: const Duration(milliseconds: 180),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDesign.radiusPanel),
            child: Container(
              height: 156,
              padding: AppDesign.itemPadding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          primaryColor.withValues(alpha: 0.16),
                          const Color(0xFF071423),
                        ]
                      : [
                          Color.lerp(Colors.white, primaryColor, 0.10)!,
                          Colors.white,
                        ],
                ),
                borderRadius: BorderRadius.circular(AppDesign.radiusPanel),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusItem,
                          ),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: primaryColor,
                          size: AppDesign.sectionIconSize,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          color: primaryColor,
                          size: AppDesign.smallActionIconSize,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF102030),
                      letterSpacing: 0.7,
                      fontSize: AppDesign.fontLabel,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppDesign.gapTiny),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryColor,
                      letterSpacing: 0.8,
                      fontSize: AppDesign.fontMicro,
                      fontWeight: FontWeight.w700,
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
