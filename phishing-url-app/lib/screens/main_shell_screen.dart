import 'package:flutter/material.dart';

import '../models/sensitivity_profile.dart';
import '../services/preferences_service.dart';
import '../services/share_intent_service.dart';
import '../widgets/chatbot_conversation_overlay.dart';
import '../widgets/robot_rain_overlay.dart';

import 'game_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';
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
  SensitivityProfile _sensitivityProfile = SensitivityProfile.balanced;
  bool _globalStorageEnabled = false;
  final PreferencesService _preferencesService = PreferencesService();

  final GlobalKey<StatsScreenState> _statsKey = GlobalKey<StatsScreenState>();
  final GlobalKey<HistoryScreenState> _historyKey =
      GlobalKey<HistoryScreenState>();
  final GlobalKey<MyHomePageState> _homeKey = GlobalKey<MyHomePageState>();

  @override
  void initState() {
    super.initState();
    _loadSensitivityProfile();
    _loadGlobalStorage();
    ShareIntentService.instance.initialize(_openSharedText);
  }

  Future<void> _loadSensitivityProfile() async {
    final profile = await _preferencesService.getSensitivityProfile();
    if (!mounted) return;
    setState(() => _sensitivityProfile = profile);
  }

  Future<void> _setSensitivityProfile(SensitivityProfile profile) async {
    await _preferencesService.setSensitivityProfile(profile);
    if (!mounted || profile == _sensitivityProfile) return;
    setState(() => _sensitivityProfile = profile);
  }

  Future<void> _loadGlobalStorage() async {
    final enabled = await _preferencesService.getGlobalStorageEnabled();
    if (!mounted) return;
    setState(() => _globalStorageEnabled = enabled);
  }

  Future<void> _setGlobalStorage(bool enabled) async {
    await _preferencesService.setGlobalStorageEnabled(enabled);
    if (!mounted || enabled == _globalStorageEnabled) return;
    setState(() => _globalStorageEnabled = enabled);
  }

  @override
  void dispose() {
    ShareIntentService.instance.dispose();
    super.dispose();
  }

  void _openSharedText(String sharedText) {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _currentIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.setSharedText(sharedText);
    });
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      _statsKey.currentState?.reload();
    }

    if (index == 2) {
      _historyKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RobotRainOverlay(
      isDark: widget.isDarkMode,
      child: ChatbotConversationOverlay(
        isDark: widget.isDarkMode,
        sensitivityProfile: _sensitivityProfile,
        onSensitivityChanged: _setSensitivityProfile,
        globalStorageEnabled: _globalStorageEnabled,
        onGlobalStorageChanged: _setGlobalStorage,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            MyHomePage(
              key: _homeKey,
              title: 'ESCÁNER',
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
              onNavigate: _changeTab,
            ),
            StatsScreen(
              key: _statsKey,
              title: 'DASHBOARD',
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
              onNavigate: _changeTab,
            ),
            HistoryScreen(
              key: _historyKey,
              title: 'HISTORIAL LOCAL',
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
              onNavigate: _changeTab,
            ),
            GameScreen(
              title: 'VIDEOJUEGOS',
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
              onNavigate: _changeTab,
            ),
            SettingsScreen(
              title: 'CONFIGURACIÓN',
              isDarkMode: widget.isDarkMode,
              onToggleTheme: widget.onToggleTheme,
              onNavigate: _changeTab,
              sensitivityProfile: _sensitivityProfile,
              onSensitivityChanged: _setSensitivityProfile,
              globalStorageEnabled: _globalStorageEnabled,
              onGlobalStorageChanged: _setGlobalStorage,
            ),
          ],
        ),
      ),
    );
  }
}
