import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _themeKey = 'isDarkMode';
  static const _hapticAlertsKey = 'hapticAlertsEnabled';

  Future<bool> getIsDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true;
  }

  Future<void> setIsDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
  }

  Future<bool> getHapticAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticAlertsKey) ?? false;
  }

  Future<void> setHapticAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticAlertsKey, value);
  }
}