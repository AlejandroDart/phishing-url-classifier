import 'package:flutter/material.dart';

import 'screens/main_shell_screen.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PreferencesService _preferencesService = PreferencesService();

  bool _isDarkMode = true;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final savedTheme = await _preferencesService.getIsDarkMode();

    if (!mounted) return;

    setState(() {
      _isDarkMode = savedTheme;
      _isReady = true;
    });
  }

  Future<void> _toggleTheme() async {
    final newValue = !_isDarkMode;

    setState(() {
      _isDarkMode = newValue;
    });

    await _preferencesService.setIsDarkMode(newValue);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Detector URL',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        fontFamily: 'monospace',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030B16),
        fontFamily: 'monospace',
      ),
      home: MainShellScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}