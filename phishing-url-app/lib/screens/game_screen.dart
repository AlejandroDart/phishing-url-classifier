import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import '../widgets/app_content_width.dart';
import '../widgets/robot_rain_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
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
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _questionIndex = 0;
  int _score = 0;
  bool _answered = false;
  bool _quizFinished = false;
  int? _selectedAnswer;

  final Set<String> _foundWords = {};
  final Set<_GridPosition> _foundCells = {};
  final List<_GridPosition> _selectedCells = [];
  String? _lastFoundWord;

  static const List<_QuizQuestion> _questionBank = [
    _QuizQuestion(
      question: '¿Cuál URL parece más sospechosa?',
      answers: [
        'https://www.google.com',
        'http://login-banco-seguro.xyz',
        'https://www.apple.com',
      ],
      correctIndex: 1,
    ),
    _QuizQuestion(
      question: '¿HTTPS garantiza que una web sea legítima?',
      answers: [
        'Sí, siempre',
        'No, solo cifra la conexión',
        'Sí, si tiene candado',
      ],
      correctIndex: 1,
    ),
    _QuizQuestion(
      question: '¿Qué señal suele aparecer en phishing?',
      answers: [
        'Mensajes con urgencia o amenazas',
        'Diseño simple',
        'Texto corto',
      ],
      correctIndex: 0,
    ),
    _QuizQuestion(
      question: '¿Qué debes hacer ante un enlace dudoso?',
      answers: [
        'Abrirlo rápido',
        'Ingresar la contraseña para comprobar',
        'Verificar el dominio antes de entrar',
      ],
      correctIndex: 2,
    ),
    _QuizQuestion(
      question: '¿Qué dato nunca deberías entregar desde un enlace recibido?',
      answers: [
        'Tu contraseña o código de verificación',
        'El nombre del banco',
        'La dirección del sitio oficial',
      ],
      correctIndex: 0,
    ),
    _QuizQuestion(
      question: '¿Cuál es la mejor forma de entrar al sitio de tu banco?',
      answers: [
        'Desde un enlace enviado por correo',
        'Escribiendo personalmente su dirección oficial',
        'Desde cualquier anuncio en redes sociales',
      ],
      correctIndex: 1,
    ),
    _QuizQuestion(
      question: '¿Qué debes revisar primero en una URL?',
      answers: [
        'El dominio real del sitio',
        'El color de la página',
        'La cantidad de imágenes',
      ],
      correctIndex: 0,
    ),
    _QuizQuestion(
      question: '¿Para qué sirve la autenticación de dos factores?',
      answers: [
        'Para eliminar todas las contraseñas',
        'Para agregar una segunda verificación de identidad',
        'Para acelerar la conexión a internet',
      ],
      correctIndex: 1,
    ),
    _QuizQuestion(
      question: '¿Qué puede indicar un mensaje con urgencia extrema?',
      answers: [
        'Una posible técnica de manipulación',
        'Que el sitio es siempre seguro',
        'Que la contraseña es correcta',
      ],
      correctIndex: 0,
    ),
  ];

  static const List<String> _wordBank = [
    'URL',
    'HTTPS',
    'LOGIN',
    'SCAM',
    'CLAVE',
    'BANCO',
    'DATOS',
    'ALERTA',
    'ENLACE',
    'FRAUDE',
    'CORREO',
    'SEGURO',
    'VIRUS',
    'HACKER',
    'WEB',
  ];

  late List<_QuizQuestion> _questions;
  late List<String> _wordSearchWords;
  late List<List<String>> _wordSearchGrid;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _questions = _createQuizSession();
    _wordSearchWords = _selectWordSearchWords();
    _wordSearchGrid = _generateWordSearchGrid();
  }

  List<_QuizQuestion> _createQuizSession() {
    final selectedQuestions = List<_QuizQuestion>.from(_questionBank)
      ..shuffle(_random);

    return selectedQuestions.take(5).map((question) {
      final answerOrder = List<int>.generate(
        question.answers.length,
        (index) => index,
      )..shuffle(_random);

      return _QuizQuestion(
        question: question.question,
        answers: answerOrder.map((index) => question.answers[index]).toList(),
        correctIndex: answerOrder.indexOf(question.correctIndex),
      );
    }).toList();
  }

  List<String> _selectWordSearchWords() {
    final words = List<String>.from(_wordBank)..shuffle(_random);
    return words.take(6).toList();
  }

  List<List<String>> _generateWordSearchGrid() {
    const gridSize = 6;
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const directions = <(int, int)>[
      (0, 1),
      (0, -1),
      (1, 0),
      (-1, 0),
      (1, 1),
      (1, -1),
      (-1, 1),
      (-1, -1),
    ];

    for (int boardAttempt = 0; boardAttempt < 200; boardAttempt++) {
      final grid = List.generate(gridSize, (_) => List.filled(gridSize, ''));
      var allWordsPlaced = true;

      final wordsToPlace = List<String>.from(_wordSearchWords)
        ..sort((first, second) => second.length.compareTo(first.length));

      for (final word in wordsToPlace) {
        final candidates = <(int, int, int, int, int)>[];

        for (int startRow = 0; startRow < gridSize; startRow++) {
          for (int startCol = 0; startCol < gridSize; startCol++) {
            for (final direction in directions) {
              final endRow = startRow + direction.$1 * (word.length - 1);
              final endCol = startCol + direction.$2 * (word.length - 1);
              if (endRow < 0 ||
                  endRow >= gridSize ||
                  endCol < 0 ||
                  endCol >= gridSize) {
                continue;
              }

              var overlaps = 0;
              var canPlace = true;
              for (int index = 0; index < word.length; index++) {
                final row = startRow + direction.$1 * index;
                final col = startCol + direction.$2 * index;
                final currentLetter = grid[row][col];
                if (currentLetter.isNotEmpty && currentLetter != word[index]) {
                  canPlace = false;
                  break;
                }
                if (currentLetter == word[index]) overlaps++;
              }

              if (canPlace) {
                candidates.add((
                  startRow,
                  startCol,
                  direction.$1,
                  direction.$2,
                  overlaps,
                ));
              }
            }
          }
        }

        if (candidates.isEmpty) {
          allWordsPlaced = false;
          break;
        }

        final maxOverlaps =
            candidates.map((candidate) => candidate.$5).reduce(math.max);
        final bestCandidates = candidates
            .where((candidate) => candidate.$5 == maxOverlaps)
            .toList()
          ..shuffle(_random);
        final selected = bestCandidates.first;

        for (int index = 0; index < word.length; index++) {
          final row = selected.$1 + selected.$3 * index;
          final col = selected.$2 + selected.$4 * index;
          grid[row][col] = word[index];
        }
      }

      if (!allWordsPlaced) continue;

      for (int row = 0; row < gridSize; row++) {
        for (int col = 0; col < gridSize; col++) {
          if (grid[row][col].isEmpty) {
            grid[row][col] = alphabet[_random.nextInt(alphabet.length)];
          }
        }
      }

      return grid;
    }

    throw StateError('No fue posible generar la sopa de letras');
  }

  Color _backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF030B16) : const Color(0xFFF4F7FB);

  Color _panelColor(bool isDark) =>
      isDark ? const Color(0xFF071423) : Colors.white;

  Color _primaryGlow(bool isDark) =>
      isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);

  Color _secondaryGlow(bool isDark) =>
      isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1);

  Color _successColor(bool isDark) =>
      isDark ? const Color(0xFF19F6A5) : const Color(0xFF00A86B);

  Color _dangerColor(bool isDark) =>
      isDark ? const Color(0xFFFF2D78) : const Color(0xFFD81B60);

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
              onPressed: widget.onToggleTheme,
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

  Widget _buildQuizGame(bool isDark) {
    if (_quizFinished) {
      return _buildQuizResult(isDark);
    }

    final question = _questions[_questionIndex];
    final accentColor = _secondaryGlow(isDark);
    final primaryColor = _primaryGlow(isDark);

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
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  Icons.psychology_alt_rounded,
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
                      'QUIZ',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: AppDesign.fontSectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: AppDesign.cardTitleLetterSpacing,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      'PONTE A PRUEBA',
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
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                ),
                child: Text(
                  '${_questionIndex + 1}/${_questions.length}',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: AppDesign.fontLabel,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reiniciar quiz',
                onPressed: _restartQuiz,
                style: IconButton.styleFrom(
                  foregroundColor: accentColor,
                  backgroundColor: accentColor.withValues(alpha: 0.10),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.28)),
                ),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapMedium),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: (_questionIndex + 1) / _questions.length,
              backgroundColor: primaryColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          Container(
            width: double.infinity,
            padding: AppDesign.itemPadding,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(color: accentColor.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREGUNTA ${_questionIndex + 1}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: AppDesign.fontMicro,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppDesign.gapSmall),
                Text(
                  question.question,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    color: _textColor(isDark),
                    fontSize: AppDesign.fontSectionTitle,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.gapStandard),
          ...List.generate(question.answers.length, (index) {
            final isSelected = _selectedAnswer == index;
            final isCorrect = question.correctIndex == index;

            Color borderColor = _primaryGlow(isDark).withValues(alpha: 0.28);
            Color backgroundColor = _backgroundColor(
              isDark,
            ).withValues(alpha: 0.45);

            if (_answered && isCorrect) {
              borderColor = _successColor(isDark);
              backgroundColor = _successColor(isDark).withValues(alpha: 0.12);
            } else if (_answered && isSelected && !isCorrect) {
              borderColor = _dangerColor(isDark);
              backgroundColor = _dangerColor(isDark).withValues(alpha: 0.12);
            }

            return Padding(
              padding: AppDesign.optionPadding,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                onTap: _answered
                    ? null
                    : () {
                        setState(() {
                          _selectedAnswer = index;
                          _answered = true;

                          if (index == question.correctIndex) {
                            _score++;
                          }
                        });
                      },
                child: Container(
                  width: double.infinity,
                  padding: AppDesign.itemPadding,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(
                      AppDesign.radiusControl,
                    ),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: AppDesign.optionBadgeSize,
                        height: AppDesign.optionBadgeSize,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              color: borderColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDesign.gapCompact),
                      Expanded(
                        child: Text(
                          question.answers[index],
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            color: _textColor(isDark),
                            fontSize: AppDesign.fontBody,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_answered && isCorrect)
                        Icon(Icons.check_circle_rounded, color: borderColor)
                      else if (_answered && isSelected)
                        Icon(Icons.cancel_rounded, color: borderColor),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppDesign.gapRegular),
          if (_answered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _questionIndex == _questions.length - 1
                      ? 'VER RESULTADO'
                      : 'SIGUIENTE',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizResult(bool isDark) {
    final percentage = (_score / _questions.length) * 100;

    String message;
    IconData icon;
    Color resultColor;

    if (percentage >= 80) {
      message = 'Excelente. Tienes muy buen criterio para detectar phishing.';
      icon = Icons.verified_rounded;
      resultColor = _successColor(isDark);
    } else if (percentage >= 50) {
      message = 'Bien. Vas por buen camino, pero aún puedes mejorar.';
      icon = Icons.shield_rounded;
      resultColor = _secondaryGlow(isDark);
    } else {
      message = 'Necesitas reforzar señales básicas de phishing.';
      icon = Icons.warning_rounded;
      resultColor = _dangerColor(isDark);
    }

    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        children: [
          Icon(icon, color: resultColor, size: AppDesign.resultIconSize),
          const SizedBox(height: AppDesign.gapStandard),
          Text(
            'RESULTADO FINAL',
            style: TextStyle(
              color: resultColor,
              fontSize: AppDesign.fontHeading,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppDesign.gapCompact),
          Text(
            'Puntaje: $_score/${_questions.length}',
            style: TextStyle(
              color: _textColor(isDark),
              fontSize: AppDesign.fontResult,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDesign.gapRegular),
          Text(
            message,
            textAlign: TextAlign.justify,
            style: TextStyle(
              color: _subtleTextColor(isDark),
              fontSize: AppDesign.fontBody,
              height: AppDesign.bodyLineHeight,
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGlow(isDark),
                foregroundColor: Colors.white,
                padding: AppDesign.buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                ),
              ),
              onPressed: _restartQuiz,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('REINICIAR QUIZ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSearchGame(bool isDark) {
    final completed = _foundWords.length == _wordSearchWords.length;
    if (completed) {
      return _buildWordSearchResult(isDark);
    }
    final accentColor = _secondaryGlow(isDark);
    final primaryColor = _primaryGlow(isDark);

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
                  borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
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
                      'SOPA DE L.',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: AppDesign.fontSectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: AppDesign.cardTitleLetterSpacing,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      'ENCUÉNTRALAS',
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
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
                ),
                child: Text(
                  '${_foundWords.length}/${_wordSearchWords.length}',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: AppDesign.fontLabel,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reiniciar sopa de letras',
                onPressed: _restartWordSearch,
                style: IconButton.styleFrom(
                  foregroundColor: accentColor,
                  backgroundColor: accentColor.withValues(alpha: 0.10),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.28)),
                ),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapMedium),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusDialog),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: _foundWords.length / _wordSearchWords.length,
              backgroundColor: primaryColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          Container(
            width: double.infinity,
            padding: AppDesign.itemPadding,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(color: accentColor.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Icon(Icons.swipe_rounded, color: accentColor, size: 22),
                const SizedBox(width: AppDesign.gapCompact),
                Expanded(
                  child: Text(
                    'Busca las palabras en cualquier dirección.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      color: _subtleTextColor(isDark),
                      fontSize: AppDesign.fontBody,
                      height: AppDesign.bodyLineHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = AppDesign.gapSmall;
              final chipWidth = (constraints.maxWidth - spacing * 2) / 3;

              return Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: spacing,
                children: _wordSearchWords.map((word) {
                  final found = _foundWords.contains(word);

                  return Container(
                    width: chipWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesign.gapSmall,
                      vertical: AppDesign.gapSmall,
                    ),
                    decoration: BoxDecoration(
                      color: found
                          ? _successColor(isDark).withValues(alpha: 0.14)
                          : _backgroundColor(isDark).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(
                        AppDesign.radiusDialog,
                      ),
                      border: Border.all(
                        color: found
                            ? _successColor(isDark)
                            : _primaryGlow(isDark).withValues(alpha: 0.28),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (found) ...[
                              Icon(
                                Icons.check_circle_rounded,
                                color: _successColor(isDark),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              word,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: found
                                    ? _successColor(isDark)
                                    : _textColor(isDark),
                                fontSize: AppDesign.fontLabel,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                decoration:
                                    found ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppDesign.gapContent),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.gapSmall,
              vertical: AppDesign.gapCompact,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              border: Border.all(color: primaryColor.withValues(alpha: 0.13)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridSize = _wordSearchGrid.length;
                final cellSize = (constraints.maxWidth / gridSize - 8).clamp(
                  26.0,
                  46.0,
                );

                return Column(
                  children: List.generate(gridSize, (row) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_wordSearchGrid[row].length, (
                        col,
                      ) {
                        final letter = _wordSearchGrid[row][col];
                        final position = _GridPosition(row, col);
                        final isSelected = _selectedCells.contains(position);
                        final isFound = _foundCells.contains(position);

                        final backgroundColor = isSelected
                            ? _secondaryGlow(isDark).withValues(alpha: 0.24)
                            : isFound
                                ? _successColor(isDark).withValues(alpha: 0.24)
                                : _backgroundColor(isDark)
                                    .withValues(alpha: 0.5);
                        final borderColor = isSelected
                            ? _secondaryGlow(isDark)
                            : isFound
                                ? _successColor(isDark)
                                : _primaryGlow(isDark).withValues(alpha: 0.35);
                        final textColor = isSelected
                            ? _secondaryGlow(isDark)
                            : isFound
                                ? _successColor(isDark)
                                : _primaryGlow(isDark);

                        return Semantics(
                          button: true,
                          selected: isSelected || isFound,
                          label:
                              'Letra $letter, fila ${row + 1}, columna ${col + 1}',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusCompact,
                            ),
                            onTap: completed
                                ? null
                                : () => _selectWordSearchCell(row, col),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: cellSize,
                              height: cellSize,
                              margin: AppDesign.gridCellMargin,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(
                                  AppDesign.radiusCompact,
                                ),
                                border: Border.all(
                                  color: borderColor,
                                  width: isSelected || isFound ? 2 : 1.2,
                                ),
                                boxShadow: isSelected || isFound
                                    ? [
                                        BoxShadow(
                                          color: borderColor.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: cellSize >= 40
                                        ? AppDesign.fontPageTitle
                                        : AppDesign.fontSectionTitle,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: AppDesign.gapStandard),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.gapCompact,
              vertical: AppDesign.gapSmall,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppDesign.radiusCompact),
              border: Border.all(color: accentColor.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: _selectedCells.isEmpty
                      ? _subtleTextColor(isDark)
                      : accentColor,
                  size: 20,
                ),
                const SizedBox(width: AppDesign.gapSmall),
                Expanded(
                  child: Text(
                    _selectedCells.isEmpty
                        ? 'SELECCIONA UNA PALABRA'
                        : _selectedLetters,
                    style: TextStyle(
                      color: _selectedCells.isEmpty
                          ? _subtleTextColor(isDark)
                          : accentColor,
                      fontSize: AppDesign.fontBody,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (_selectedCells.isNotEmpty)
                  IconButton(
                    tooltip: 'Limpiar selección',
                    onPressed: _clearWordSearchSelection,
                    icon: Icon(
                      Icons.backspace_outlined,
                      color: accentColor,
                      size: AppDesign.smallActionIconSize,
                    ),
                  ),
              ],
            ),
          ),
          if (_lastFoundWord != null) ...[
            const SizedBox(height: AppDesign.gapItem),
            Center(
              child: Text(
                '¡Encontraste $_lastFoundWord!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _successColor(isDark),
                  fontSize: AppDesign.fontSubtitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordSearchResult(bool isDark) {
    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _glowBox(isDark: isDark, radius: AppDesign.radiusCard),
      child: Column(
        children: [
          Icon(
            Icons.verified_rounded,
            color: _successColor(isDark),
            size: AppDesign.resultIconSize,
          ),
          const SizedBox(height: AppDesign.gapStandard),
          Text(
            'RESULTADO FINAL',
            style: TextStyle(
              color: _successColor(isDark),
              fontSize: AppDesign.fontHeading,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppDesign.gapCompact),
          Text(
            'Palabras: ${_foundWords.length}/${_wordSearchWords.length}',
            style: TextStyle(
              color: _textColor(isDark),
              fontSize: AppDesign.fontResult,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDesign.gapRegular),
          Text(
            'Excelente. Completaste la sopa de letras de ciberseguridad.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subtleTextColor(isDark),
              fontSize: AppDesign.fontBody,
              height: AppDesign.bodyLineHeight,
            ),
          ),
          const SizedBox(height: AppDesign.gapMedium),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGlow(isDark),
                foregroundColor: Colors.white,
                padding: AppDesign.buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.radiusControl),
                ),
              ),
              onPressed: _restartWordSearch,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('REINICIAR SOPA'),
            ),
          ),
        ],
      ),
    );
  }

  String get _selectedLetters => _selectedCells
      .map((position) => _wordSearchGrid[position.row][position.col])
      .join();

  void _selectWordSearchCell(int row, int col) {
    final position = _GridPosition(row, col);

    setState(() {
      if (_selectedCells.isNotEmpty && _selectedCells.last == position) {
        _selectedCells.removeLast();
        return;
      }

      if (_selectedCells.contains(position)) {
        return;
      }

      if (_selectedCells.isNotEmpty && !_isValidNextCell(position)) {
        return;
      }

      _selectedCells.add(position);

      final selected = _selectedLetters;
      final reversed = selected.split('').reversed.join();
      String? matchingWord;
      for (final word in _wordSearchWords) {
        if (!_foundWords.contains(word) &&
            (word == selected || word == reversed)) {
          matchingWord = word;
          break;
        }
      }

      if (matchingWord != null) {
        _foundWords.add(matchingWord);
        _foundCells.addAll(_selectedCells);
        _selectedCells.clear();
        _lastFoundWord = matchingWord;
        return;
      }

      final maxWordLength = _wordSearchWords
          .map((word) => word.length)
          .reduce((current, length) => current > length ? current : length);
      if (_selectedCells.length >= maxWordLength) {
        _selectedCells.clear();
      }
    });
  }

  bool _isValidNextCell(_GridPosition candidate) {
    final previous = _selectedCells.last;
    final rowStep = candidate.row - previous.row;
    final colStep = candidate.col - previous.col;

    final isAdjacent = rowStep.abs() <= 1 &&
        colStep.abs() <= 1 &&
        (rowStep != 0 || colStep != 0);
    if (!isAdjacent) return false;

    if (_selectedCells.length == 1) return true;

    final first = _selectedCells[0];
    final second = _selectedCells[1];
    final expectedRowStep = second.row - first.row;
    final expectedColStep = second.col - first.col;

    return rowStep == expectedRowStep && colStep == expectedColStep;
  }

  void _clearWordSearchSelection() {
    setState(() {
      _selectedCells.clear();
    });
  }

  void _restartWordSearch() {
    setState(() {
      _wordSearchWords = _selectWordSearchWords();
      _wordSearchGrid = _generateWordSearchGrid();
      _foundWords.clear();
      _foundCells.clear();
      _selectedCells.clear();
      _lastFoundWord = null;
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_questionIndex == _questions.length - 1) {
        _quizFinished = true;
      } else {
        _questionIndex++;
      }

      _answered = false;
      _selectedAnswer = null;
    });
  }

  void _restartQuiz() {
    setState(() {
      _questions = _createQuizSession();
      _questionIndex = 0;
      _score = 0;
      _answered = false;
      _quizFinished = false;
      _selectedAnswer = null;
    });
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
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: AppDesign.gapLarge),
      ],
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    const selectedIndex = 3;

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
                child: SingleChildScrollView(
                  padding: AppDesign.pagePadding,
                  child: AppContentWidth(
                    child: Column(
                      children: [
                        _buildQuizGame(isDark),
                        const SizedBox(height: AppDesign.gapBetweenCards),
                        _buildWordSearchGame(isDark),
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

class _QuizQuestion {
  const _QuizQuestion({
    required this.question,
    required this.answers,
    required this.correctIndex,
  });

  final String question;
  final List<String> answers;
  final int correctIndex;
}

class _GridPosition {
  const _GridPosition(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GridPosition && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);
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
