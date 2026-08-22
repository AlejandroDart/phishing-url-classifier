import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sensitivity_profile.dart';
import '../services/api_service.dart';
import '../theme/app_design.dart';

String _newConversationId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = math.Random.secure().nextInt(0x7fffffff);
  return 'mobile-$timestamp-$random';
}

class ChatbotConversationOverlay extends StatefulWidget {
  const ChatbotConversationOverlay({
    super.key,
    required this.isDark,
    required this.child,
    required this.sensitivityProfile,
    required this.onSensitivityChanged,
    required this.globalStorageEnabled,
    required this.onGlobalStorageChanged,
  });

  final bool isDark;
  final Widget child;
  final SensitivityProfile sensitivityProfile;
  final Future<void> Function(SensitivityProfile) onSensitivityChanged;
  final bool globalStorageEnabled;
  final Future<void> Function(bool) onGlobalStorageChanged;

  @override
  State<ChatbotConversationOverlay> createState() =>
      _ChatbotConversationOverlayState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.isError = false,
    this.intent,
    this.generationMode,
    this.analysis,
    this.decision,
  });

  final String role;
  final String content;
  final List<String> sources;
  final bool isError;
  final String? intent;
  final String? generationMode;
  final Map<String, dynamic>? analysis;
  final Map<String, dynamic>? decision;

  bool get isUser => role == 'user';
  bool get isAnalysisResult =>
      !isUser && !isError && intent == 'url_analysis' && analysis != null;
  bool get isFactorResult =>
      !isUser &&
      !isError &&
      analysis != null &&
      const {'shap_top_factor', 'shap_least_factor'}.contains(generationMode);

  Map<String, String> toPayload() => {
        'role': role,
        'content': content,
      };
}

class _ChatbotConversationOverlayState
    extends State<ChatbotConversationOverlay> {
  final TextEditingController _textController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  String _conversationId = _newConversationId();
  Offset? _position;
  bool _isSending = false;
  late SensitivityProfile _activeSensitivityProfile;

  @override
  void initState() {
    super.initState();
    _activeSensitivityProfile = widget.sensitivityProfile;
  }

  @override
  void didUpdateWidget(covariant ChatbotConversationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensitivityProfile != widget.sensitivityProfile) {
      _activeSensitivityProfile = widget.sensitivityProfile;
    }
  }

  Color get _panelColor =>
      widget.isDark ? const Color(0xFF071423) : Colors.white;

  Color get _surfaceColor =>
      widget.isDark ? const Color(0xFF091C30) : const Color(0xFFF2F7FC);

  Color get _primaryColor =>
      widget.isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);

  Color get _secondaryColor =>
      widget.isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);

  Color get _textColor =>
      widget.isDark ? Colors.white : const Color(0xFF102030);

  Color get _subtleTextColor =>
      widget.isDark ? const Color(0xFF6FB6FF) : const Color(0xFF376D9A);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage({
    required BuildContext sheetContext,
    required StateSetter updateSheet,
    required ScrollController scrollController,
  }) async {
    final question = _textController.text.trim();
    if (question.isEmpty || _isSending) return;

    final history = _messages
        .where((message) => !message.isError)
        .map((message) => message.toPayload())
        .toList();

    _textController.clear();
    updateSheet(() {
      _messages.add(_ChatMessage(role: 'user', content: question));
      _isSending = true;
    });
    _scrollToBottom(scrollController);

    try {
      final reply = await askChatbot(
        question,
        history: history,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      final action = reply.action;
      if (action?['type'] == 'set_sensitivity') {
        final profile = SensitivityProfile.fromApiValue(
          action?['value']?.toString(),
        );
        _activeSensitivityProfile = profile;
        await widget.onSensitivityChanged(profile);
      } else if (action?['type'] == 'set_global_storage') {
        final enabled = action?['value'] == true;
        await widget.onGlobalStorageChanged(enabled);
      }
      _messages.add(
        _ChatMessage(
          role: 'assistant',
          content: reply.answer,
          sources: reply.sources,
          intent: reply.intent,
          generationMode: reply.generationMode,
          analysis: reply.analysis,
          decision: reply.decision,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final cleanError =
          error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _messages.add(
        _ChatMessage(
          role: 'assistant',
          content: cleanError,
          isError: true,
        ),
      );
    } finally {
      if (mounted) _isSending = false;
      if (sheetContext.mounted) {
        updateSheet(() {});
        _scrollToBottom(scrollController);
      }
    }
  }

  void _showConversation() {
    FocusManager.instance.primaryFocus?.unfocus();
    final scrollController = ScrollController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final keyboardVisible = keyboardHeight > 0;
        final isLandscape = mediaQuery.orientation == Orientation.landscape;

        return SafeArea(
          minimum: const EdgeInsets.all(AppDesign.gapSmall),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: LayoutBuilder(
              builder: (layoutContext, constraints) {
                final heightFactor = keyboardVisible
                    ? 0.90
                    : isLandscape
                        ? 0.90
                        : 0.82;
                final usableHeight = math.max(
                  0.0,
                  constraints.maxHeight - (AppDesign.gapStandard * 2),
                );
                final panelHeight = math
                    .min(usableHeight, constraints.maxHeight * heightFactor)
                    .toDouble();

                return StatefulBuilder(
                  builder: (sheetContext, updateSheet) {
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: panelHeight,
                        margin: const EdgeInsets.all(AppDesign.gapSmall),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.34),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Material(
                          color: _panelColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusDialog,
                            ),
                            side: BorderSide(
                              color: _secondaryColor.withValues(alpha: 0.65),
                              width: 1.4,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _buildHeader(sheetContext, updateSheet),
                              Divider(
                                height: 1,
                                color: _secondaryColor.withValues(alpha: 0.18),
                              ),
                              Expanded(
                                child: _messages.isEmpty
                                    ? _buildEmptyState(
                                        compact: keyboardVisible || isLandscape,
                                      )
                                    : ListView.builder(
                                        controller: scrollController,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppDesign.gapStandard,
                                          vertical: AppDesign.gapCompact,
                                        ),
                                        itemCount: _messages.length +
                                            (_isSending ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index == _messages.length) {
                                            return _buildTypingBubble();
                                          }
                                          return _buildMessageBubble(
                                            _messages[index],
                                          );
                                        },
                                      ),
                              ),
                              _buildComposer(
                                sheetContext,
                                updateSheet,
                                scrollController,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(scrollController.dispose);
  }

  Widget _buildHeader(BuildContext context, StateSetter updateSheet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _secondaryColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppDesign.radiusItem),
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: _secondaryColor,
              size: AppDesign.topBarActionIconSize,
            ),
          ),
          const SizedBox(width: AppDesign.gapCompact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANITA',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: AppDesign.fontSectionTitle,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Asistente de LinkShield AI',
                  style: TextStyle(
                    color: _subtleTextColor,
                    fontSize: AppDesign.fontCaption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _secondaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
              border: Border.all(
                color: _secondaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              _activeSensitivityProfile.label.toUpperCase(),
              style: TextStyle(
                color: _secondaryColor,
                fontSize: AppDesign.fontMicro,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.gapXSmall),
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Nueva conversación',
              onPressed: _isSending
                  ? null
                  : () {
                      updateSheet(() {
                        _messages.clear();
                        _conversationId = _newConversationId();
                      });
                      _textController.clear();
                    },
              icon: Icon(Icons.delete_sweep_outlined, color: _subtleTextColor),
            ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: _primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool compact}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? AppDesign.gapSmall : AppDesign.gapSection,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(
                Icons.forum_outlined,
                color: _secondaryColor,
                size: 46,
              ),
              const SizedBox(height: AppDesign.gapCompact),
            ],
            Text(
              'INICIA UNA CONVERSACIÓN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryColor,
                fontSize:
                    compact ? AppDesign.fontLabel : AppDesign.fontSubtitle,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: AppDesign.gapSmall),
              Text(
                'Pregunta sobre phishing, enlaces o cómo utilizar la aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subtleTextColor,
                  fontSize: AppDesign.fontBody,
                  height: AppDesign.bodyLineHeight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    if (message.isAnalysisResult) {
      return _buildAnalysisResult(message);
    }
    if (message.isFactorResult) {
      return _buildFactorExplanation(message);
    }

    final bubbleColor = message.isUser
        ? _primaryColor.withValues(alpha: widget.isDark ? 0.28 : 0.14)
        : message.isError
            ? Colors.redAccent.withValues(alpha: 0.12)
            : _surfaceColor;
    final borderColor = message.isUser
        ? _primaryColor.withValues(alpha: 0.55)
        : message.isError
            ? Colors.redAccent.withValues(alpha: 0.45)
            : _secondaryColor.withValues(alpha: 0.28);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppDesign.gapCompact),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.gapItem,
          vertical: AppDesign.gapCompact,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppDesign.radiusControl),
            topRight: const Radius.circular(AppDesign.radiusControl),
            bottomLeft: Radius.circular(
              message.isUser ? AppDesign.radiusControl : AppDesign.radiusSmall,
            ),
            bottomRight: Radius.circular(
              message.isUser ? AppDesign.radiusSmall : AppDesign.radiusControl,
            ),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isUser
                      ? Icons.person_outline_rounded
                      : message.isError
                          ? Icons.error_outline_rounded
                          : Icons.smart_toy_outlined,
                  color: message.isError
                      ? Colors.redAccent
                      : message.isUser
                          ? _primaryColor
                          : _secondaryColor,
                  size: 16,
                ),
                const SizedBox(width: AppDesign.gapXSmall),
                Text(
                  message.isUser ? 'TÚ' : 'ANITA',
                  style: TextStyle(
                    color: message.isError
                        ? Colors.redAccent
                        : message.isUser
                            ? _primaryColor
                            : _secondaryColor,
                    fontSize: AppDesign.fontMicro,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.gapSmall),
            Text(
              message.content,
              style: TextStyle(
                color: _textColor,
                fontSize: AppDesign.fontBody,
                height: AppDesign.bodyLineHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult(_ChatMessage message) {
    final analysis = message.analysis!;
    final probability = (analysis['probability'] as num?)?.toDouble() ?? 0;
    final percentage = (probability * 100).clamp(0, 100).toDouble();
    final isPhishing = analysis['classification']?.toString() == 'phishing';
    final statusColor =
        isPhishing ? const Color(0xFFFF5C7A) : const Color(0xFF43D4A5);
    final statusLabel = isPhishing ? 'PHISHING DETECTADO' : 'NO PHISHING';
    final profile = SensitivityProfile.fromApiValue(
      analysis['sensitivity_profile']?.toString(),
    );
    final effectiveThreshold =
        (analysis['effective_threshold'] as num?)?.toDouble() ?? 0.5;
    final url = analysis['url']?.toString() ?? 'URL no disponible';
    final shap = analysis['shap_explanation'];
    final topFactors = shap is Map<String, dynamic>
        ? (shap['feature_factors'] as List? ??
                shap['top_factors'] as List? ??
                const [])
            .take(3)
            .toList()
        : const [];
    final riskLevel = message.decision?['risk_level']?.toString();
    final recommendation = switch (riskLevel) {
      'high' =>
        'No abras el enlace ni ingreses credenciales o datos personales.',
      'moderate' =>
        'Verifica el dominio por un canal oficial antes de continuar.',
      _ =>
        'Mantén la precaución y confirma siempre que el dominio sea el oficial.',
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        margin: const EdgeInsets.only(bottom: AppDesign.gapCompact),
        padding: const EdgeInsets.all(AppDesign.gapStandard),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(AppDesign.radiusControl),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.48),
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: widget.isDark ? 0.08 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  ),
                  child: Icon(
                    isPhishing
                        ? Icons.gpp_bad_outlined
                        : Icons.verified_user_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDesign.gapRegular),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ANÁLISIS COMPLETADO',
                        style: TextStyle(
                          color: _subtleTextColor,
                          fontSize: AppDesign.fontMicro,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapTiny),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: AppDesign.fontSubtitle,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: AppDesign.fontResult,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.gapCompact),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link_rounded, color: _subtleTextColor, size: 17),
                const SizedBox(width: AppDesign.gapXSmall),
                Expanded(
                  child: Text(
                    url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: AppDesign.fontCaption,
                      fontWeight: FontWeight.w600,
                      height: AppDesign.bodyLineHeight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.gapRegular),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 7,
                backgroundColor: _subtleTextColor.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: AppDesign.gapTiny),
            Text(
              'Probabilidad estimada de phishing',
              style: TextStyle(
                color: _subtleTextColor,
                fontSize: AppDesign.fontMicro,
              ),
            ),
            const SizedBox(height: AppDesign.gapSmall),
            Wrap(
              spacing: AppDesign.gapSmall,
              runSpacing: AppDesign.gapSmall,
              children: [
                _buildAnalysisMetadataChip(
                  Icons.tune_rounded,
                  'Perfil ${profile.label}',
                ),
                _buildAnalysisMetadataChip(
                  Icons.vertical_align_center_rounded,
                  'Umbral ${(effectiveThreshold * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
            if (topFactors.isNotEmpty) ...[
              const SizedBox(height: AppDesign.gapStandard),
              Divider(
                height: 1,
                color: _subtleTextColor.withValues(alpha: 0.20),
              ),
              const SizedBox(height: AppDesign.gapCompact),
              Text(
                'FACTORES CON MAYOR INFLUENCIA',
                style: TextStyle(
                  color: _subtleTextColor,
                  fontSize: AppDesign.fontMicro,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: AppDesign.gapSmall),
              for (final rawFactor in topFactors)
                _buildAnalysisFactor(rawFactor),
            ],
            const SizedBox(height: AppDesign.gapRegular),
            Divider(
              height: 1,
              color: _subtleTextColor.withValues(alpha: 0.20),
            ),
            const SizedBox(height: AppDesign.gapRegular),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: _secondaryColor, size: 18),
                const SizedBox(width: AppDesign.gapSmall),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: AppDesign.fontCaption,
                      height: AppDesign.bodyLineHeight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisMetadataChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _secondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
        border: Border.all(
          color: _secondaryColor.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _secondaryColor, size: 14),
          const SizedBox(width: AppDesign.gapXSmall),
          Text(
            label,
            style: TextStyle(
              color: _subtleTextColor,
              fontSize: AppDesign.fontMicro,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisFactor(dynamic rawFactor) {
    final factor = rawFactor is Map
        ? Map<String, dynamic>.from(rawFactor)
        : <String, dynamic>{};
    final value = (factor['shap_value'] as num?)?.toDouble() ?? 0;
    final increasesRisk = value > 0;
    final effectColor =
        increasesRisk ? const Color(0xFFFF5C7A) : const Color(0xFF43D4A5);
    final label = factor['display_name']?.toString() ??
        factor['feature']?.toString() ??
        'Característica';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.gapSmall),
      child: Row(
        children: [
          Icon(
            increasesRisk
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: effectColor,
            size: 17,
          ),
          const SizedBox(width: AppDesign.gapXSmall),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor,
                fontSize: AppDesign.fontCaption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.gapSmall),
          Text(
            factor['scope'] == 'branch_probability'
                ? '${increasesRisk ? '+' : '-'}${(value.abs() * 100).toStringAsFixed(1)} pts RF'
                : '${increasesRisk ? '+' : '-'}${(value.abs() * 100).toStringAsFixed(1)} pts',
            style: TextStyle(
              color: effectColor,
              fontSize: AppDesign.fontCaption,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorExplanation(_ChatMessage message) {
    final analysis = message.analysis!;
    final shap = analysis['shap_explanation'];
    final rawFactors = shap is Map<String, dynamic>
        ? (shap['all_feature_contributions'] as List? ??
            shap['feature_factors'] as List? ??
            shap['all_contributions'] as List? ??
            const [])
        : const [];
    final factors =
        rawFactors.whereType<Map>().map(Map<String, dynamic>.from).toList();
    if (factors.isEmpty) {
      return _buildPlainAssistantBubble(message);
    }

    final isTop = message.generationMode == 'shap_top_factor';
    factors.sort((a, b) {
      final first = ((a['shap_value'] as num?)?.toDouble() ?? 0).abs();
      final second = ((b['shap_value'] as num?)?.toDouble() ?? 0).abs();
      return first.compareTo(second);
    });
    final factor = isTop ? factors.last : factors.first;
    final shapValue = (factor['shap_value'] as num?)?.toDouble() ?? 0;
    final impact = shapValue.abs() * 100;
    final increasesRisk = shapValue > 0;
    final neutral = shapValue.abs() <= 0.000000000001;
    final impactColor = neutral
        ? _subtleTextColor
        : increasesRisk
            ? const Color(0xFFFF5C7A)
            : const Color(0xFF43D4A5);
    final label = factor['display_name']?.toString() ??
        factor['feature']?.toString() ??
        'Característica';
    final description = factor['description']?.toString() ?? '';
    final valueMeaning = factor['raw_value_meaning']?.toString() ?? '';
    final effectText = neutral
        ? 'No modificó la probabilidad'
        : increasesRisk
            ? 'Aumentó la probabilidad de phishing'
            : 'Redujo la probabilidad de phishing';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        margin: const EdgeInsets.only(bottom: AppDesign.gapCompact),
        padding: const EdgeInsets.all(AppDesign.gapStandard),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(AppDesign.radiusControl),
          border: Border.all(color: impactColor.withValues(alpha: 0.50)),
          boxShadow: [
            BoxShadow(
              color: impactColor.withValues(alpha: widget.isDark ? 0.09 : 0.13),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: _secondaryColor, size: 20),
                const SizedBox(width: AppDesign.gapSmall),
                Expanded(
                  child: Text(
                    'EXPLICABILIDAD SHAP',
                    style: TextStyle(
                      color: _secondaryColor,
                      fontSize: AppDesign.fontMicro,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesign.gapSmall,
                    vertical: AppDesign.gapTiny,
                  ),
                  decoration: BoxDecoration(
                    color: impactColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  ),
                  child: Text(
                    isTop ? 'MAYOR IMPACTO' : 'MENOR IMPACTO',
                    style: TextStyle(
                      color: impactColor,
                      fontSize: AppDesign.fontMicro,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.gapStandard),
            Text(
              label,
              style: TextStyle(
                color: _textColor,
                fontSize: AppDesign.fontHeading,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: AppDesign.gapSmall),
              Text(
                description,
                style: TextStyle(
                  color: _subtleTextColor,
                  fontSize: AppDesign.fontCaption,
                  height: AppDesign.bodyLineHeight,
                ),
              ),
            ],
            const SizedBox(height: AppDesign.gapStandard),
            Divider(
              height: 1,
              color: _subtleTextColor.withValues(alpha: 0.20),
            ),
            const SizedBox(height: AppDesign.gapCompact),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMPACTO EN LA PROBABILIDAD',
                        style: TextStyle(
                          color: _subtleTextColor,
                          fontSize: AppDesign.fontMicro,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: AppDesign.gapTiny),
                      Text(
                        effectText,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: AppDesign.fontCaption,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.gapRegular),
                Text(
                  '${increasesRisk ? '+' : neutral ? '' : '-'}${impact.toStringAsFixed(1)} pts',
                  style: TextStyle(
                    color: impactColor,
                    fontSize: AppDesign.fontResult,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (valueMeaning.isNotEmpty) ...[
              const SizedBox(height: AppDesign.gapCompact),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.data_object_rounded,
                    color: _subtleTextColor,
                    size: 17,
                  ),
                  const SizedBox(width: AppDesign.gapXSmall),
                  Expanded(
                    child: Text(
                      valueMeaning,
                      style: TextStyle(
                        color: _subtleTextColor,
                        fontSize: AppDesign.fontCaption,
                        height: AppDesign.bodyLineHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDesign.gapRegular),
            Text(
              'Esta característica influye junto con las otras 24 variables del modelo.',
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.78),
                fontSize: AppDesign.fontMicro,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlainAssistantBubble(_ChatMessage message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppDesign.gapCompact),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.gapItem,
          vertical: AppDesign.gapCompact,
        ),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(AppDesign.radiusControl),
          border: Border.all(
            color: _secondaryColor.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: _textColor,
            fontSize: AppDesign.fontBody,
            height: AppDesign.bodyLineHeight,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDesign.gapCompact),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(AppDesign.radiusControl),
          border: Border.all(
            color: _secondaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(width: AppDesign.gapSmall),
            Text(
              'Escribiendo...',
              style: TextStyle(
                color: _subtleTextColor,
                fontSize: AppDesign.fontCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(
    BuildContext sheetContext,
    StateSetter updateSheet,
    ScrollController scrollController,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _surfaceColor.withValues(alpha: 0.72),
        border: Border(
          top: BorderSide(
            color: _secondaryColor.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: TextField(
        controller: _textController,
        enabled: !_isSending,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendMessage(
          sheetContext: sheetContext,
          updateSheet: updateSheet,
          scrollController: scrollController,
        ),
        decoration: InputDecoration(
          hintText: 'Escribe tu pregunta...',
          prefixIcon: Icon(Icons.chat_bubble_outline, color: _subtleTextColor),
          suffixIcon: IconButton(
            tooltip: 'Enviar',
            onPressed: _isSending
                ? null
                : () => _sendMessage(
                      sheetContext: sheetContext,
                      updateSheet: updateSheet,
                      scrollController: scrollController,
                    ),
            icon: Icon(Icons.send_rounded, color: _secondaryColor),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultPosition = Offset(
          constraints.maxWidth -
              AppDesign.chatbotButtonSize -
              AppDesign.chatbotScreenMargin,
          constraints.maxHeight -
              AppDesign.chatbotButtonSize -
              AppDesign.chatbotBottomClearance,
        );
        final currentPosition = _position ?? defaultPosition;
        final maxLeft = math
            .max(
              AppDesign.chatbotScreenMargin,
              constraints.maxWidth -
                  AppDesign.chatbotButtonSize -
                  AppDesign.chatbotScreenMargin,
            )
            .toDouble();
        final maxTop = math
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

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              left: safePosition.dx,
              top: safePosition.dy,
              child: Semantics(
                button: true,
                label: 'Abrir asistente virtual',
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _position = Offset(
                        (safePosition.dx + details.delta.dx)
                            .clamp(AppDesign.chatbotScreenMargin, maxLeft)
                            .toDouble(),
                        (safePosition.dy + details.delta.dy)
                            .clamp(120.0, maxTop)
                            .toDouble(),
                      );
                    });
                  },
                  onLongPress: () => setState(() => _position = null),
                  onTap: _showConversation,
                  child: Container(
                    width: AppDesign.chatbotButtonSize,
                    height: AppDesign.chatbotButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _panelColor,
                      border: Border.all(
                        color: _secondaryColor.withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _secondaryColor.withValues(alpha: 0.32),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: _secondaryColor,
                      size: AppDesign.sectionIconSize,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
