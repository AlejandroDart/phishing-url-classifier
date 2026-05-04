import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final Future<void> Function() onToggleTheme;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        MyHomePage(
          title: 'PHISHING URL DETECTOR',
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          onNavigate: _changeTab,
        ),
        StatsScreen(
          title: 'DASHBOARD',
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          onNavigate: _changeTab,
        ),
        SettingsScreen(
          title: 'CONFIGURACIÓN',
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          onNavigate: _changeTab,
        ),
      ],
    );
  }
}