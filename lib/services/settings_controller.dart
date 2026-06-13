import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences (currently the theme mode), persisted with
/// shared_preferences and exposed as a [ChangeNotifier] so the UI rebuilds
/// when they change.
class SettingsController extends ChangeNotifier {
  static const _themeModeKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = _decode(prefs.getString(_themeModeKey));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Convenience toggle used by the home-screen icon: flips between light and
  /// dark based on what is currently being shown.
  Future<void> toggle(Brightness current) {
    return setThemeMode(
      current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
