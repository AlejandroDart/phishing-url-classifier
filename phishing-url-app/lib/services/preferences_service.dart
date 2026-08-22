import 'package:shared_preferences/shared_preferences.dart';

import '../models/sensitivity_profile.dart';

class PreferencesService {
  static const _themeKey = 'isDarkMode';
  static const _hapticAlertsKey = 'hapticAlertsEnabled';
  static const _globalStorageKey = 'globalStorageEnabled';
  static const _selectedModelKey = 'selectedPredictionModel';
  static const _sensitivityProfileKey = 'sensitivityProfile';
  static const defaultModelId = 'hybrid_ensemble';

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

  Future<bool> getGlobalStorageEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_globalStorageKey) ?? false;
  }

  Future<void> setGlobalStorageEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalStorageKey, value);
  }

  Future<String> getSelectedModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedModelKey) ?? defaultModelId;
  }

  Future<void> setSelectedModelId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, value);
  }

  Future<SensitivityProfile> getSensitivityProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return SensitivityProfile.fromApiValue(
      prefs.getString(_sensitivityProfileKey),
    );
  }

  Future<void> setSensitivityProfile(SensitivityProfile value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sensitivityProfileKey, value.apiValue);
  }
}
