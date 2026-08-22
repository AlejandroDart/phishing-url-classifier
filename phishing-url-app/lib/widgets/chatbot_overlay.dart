import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_design.dart';

class ChatbotOverlay extends StatefulWidget {
  const ChatbotOverlay({
    super.key,
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  State<ChatbotOverlay> createState() => _ChatbotOverlayState();
}

class _ChatbotOverlayState extends State<ChatbotOverlay> {
  final TextEditingController _textController = TextEditingController();
  Offset? _position;

  Color get _panelColor =>
      widget.isDark ? const Color(0xFF071423) : Colors.white;

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

  void _showPanel() {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String? statusMessage;
        String? sourceMessage;
        bool isError = false;
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitMessage() async {
              final message = _textController.text.trim();
              if (message.isEmpty || isSending) return;
              _textController.clear();
              setModalState(() {
                isSending = true;
                isError = false;
                statusMessage = null;
                sourceMessage = null;
              });

              try {
                final reply = await askChatbot(message);
                if (!context.mounted) return;
                setModalState(() {
                  statusMessage = reply.answer;
                  sourceMessage = reply.sources.isEmpty
                      ? null
                      : 'Fuentes: ${reply.sources.join(' · ')}';
                });
              } catch (error) {
                if (!context.mounted) return;
                final cleanError = error
                    .toString()
                    .replaceFirst(RegExp(r'^Exception:\s*'), '');
                setModalState(() {
                  isError = true;
                  statusMessage = cleanError;
                });
              } finally {
                if (context.mounted) {
                  setModalState(() => isSending = false);
                }
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                margin: AppDesign.detailsSheetMargin,
                padding: AppDesign.detailsSheetPadding,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                  border: Border.all(
                    color: _secondaryColor.withValues(alpha: 0.65),
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: AppDesign.topBarIconBoxSize,
                              height: AppDesign.topBarIconBoxSize,
                              decoration: BoxDecoration(
                                color: _secondaryColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppDesign.radiusItem,
                                ),
                              ),
                              child: Icon(
                                Icons.smart_toy_rounded,
                                color: _secondaryColor,
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
                                      color: _primaryColor,
                                      fontSize: AppDesign.fontSectionTitle,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: AppDesign.gapTiny),
                                  Text(
                                    'Guía inteligente de LinkShield AI',
                                    style: TextStyle(
                                      color: _subtleTextColor,
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
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesign.gapContent),
                        Text(
                          'Pregunta sobre phishing, enlaces o el uso de la app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: AppDesign.fontBody,
                            height: AppDesign.bodyLineHeight,
                          ),
                        ),
                        const SizedBox(height: AppDesign.gapStandard),
                        TextField(
                          controller: _textController,
                          enabled: !isSending,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => submitMessage(),
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            suffixIcon: IconButton(
                              tooltip: 'Enviar',
                              onPressed: isSending ? null : submitMessage,
                              icon: Icon(
                                Icons.send_rounded,
                                color: _secondaryColor,
                              ),
                            ),
                          ),
                        ),
                        if (isSending) ...[
                          const SizedBox(height: AppDesign.gapCompact),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _secondaryColor,
                                ),
                              ),
                              const SizedBox(width: AppDesign.gapSmall),
                              Flexible(
                                child: Text(
                                  'Consultando la base de conocimiento...',
                                  style: TextStyle(
                                    color: _subtleTextColor,
                                    fontSize: AppDesign.fontCaption,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (statusMessage != null) ...[
                          const SizedBox(height: AppDesign.gapCompact),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(AppDesign.gapStandard),
                            decoration: BoxDecoration(
                              color:
                                  (isError ? Colors.redAccent : _secondaryColor)
                                      .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                AppDesign.radiusItem,
                              ),
                              border: Border.all(
                                color: (isError
                                        ? Colors.redAccent
                                        : _secondaryColor)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isError
                                          ? Icons.error_outline_rounded
                                          : Icons.smart_toy_outlined,
                                      color: isError
                                          ? Colors.redAccent
                                          : _secondaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppDesign.gapSmall),
                                    Text(
                                      isError ? 'NO DISPONIBLE' : 'RESPUESTA',
                                      style: TextStyle(
                                        color: isError
                                            ? Colors.redAccent
                                            : _secondaryColor,
                                        fontSize: AppDesign.fontCaption,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppDesign.gapSmall),
                                Text(
                                  statusMessage!,
                                  style: TextStyle(
                                    color: _textColor,
                                    fontSize: AppDesign.fontBody,
                                    height: AppDesign.bodyLineHeight,
                                  ),
                                ),
                                if (sourceMessage != null) ...[
                                  const SizedBox(height: AppDesign.gapSmall),
                                  Text(
                                    sourceMessage!,
                                    style: TextStyle(
                                      color: _subtleTextColor,
                                      fontSize: AppDesign.fontCaption,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDesign.gapStandard),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
                  onLongPress: () {
                    setState(() {
                      _position = null;
                    });
                  },
                  onTap: _showPanel,
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
