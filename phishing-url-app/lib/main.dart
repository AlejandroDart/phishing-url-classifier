import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'screens/main_shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/preferences_service.dart';
import 'services/share_intent_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    debugPaintBaselinesEnabled = false;
    return true;
  }());
  final initialDarkMode = await PreferencesService().getIsDarkMode();
  runApp(MyApp(initialDarkMode: initialDarkMode));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialDarkMode});

  final bool initialDarkMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PreferencesService _preferencesService = PreferencesService();

  late bool _isDarkMode;
  bool _showSplash = !kIsWeb;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  Future<void> _toggleTheme() async {
    final newValue = !_isDarkMode;

    setState(() {
      _isDarkMode = newValue;
    });

    await _preferencesService.setIsDarkMode(newValue);
    await ShareIntentService.instance.setThemeMode(newValue);
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);
    final surface = isDark ? const Color(0xFF071423) : Colors.white;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF030B16) : const Color(0xFFF4F7FB),
      fontFamily: 'monospace',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: surface,
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primary.withValues(alpha: 0.15),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? Colors.white54
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : const Color(0xFF41506A),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: isDark ? 0.82 : 0.95),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LinkShield AI',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: _showSplash
          ? SplashScreen(
              onComplete: () {
                if (!mounted) return;
                setState(() {
                  _showSplash = false;
                });
              },
            )
          : MainShellScreen(
              isDarkMode: _isDarkMode,
              onToggleTheme: _toggleTheme,
            ),
    );
  }
}
