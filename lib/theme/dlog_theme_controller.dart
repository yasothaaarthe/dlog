import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DLogThemeController extends ChangeNotifier {
  DLogThemeController._();

  static final DLogThemeController instance = DLogThemeController._();
  static const _preferenceKey = 'dlog_light_mode_enabled';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isLightMode => _themeMode == ThemeMode.light;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _themeMode = preferences.getBool(_preferenceKey) == true
          ? ThemeMode.light
          : ThemeMode.dark;
    } catch (error) {
      debugPrint('DLOG THEME LOAD ERROR: $error');
      _themeMode = ThemeMode.dark;
    }
  }

  Future<void> setLightMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.light : ThemeMode.dark;
    if (_themeMode == nextMode) return;

    _themeMode = nextMode;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_preferenceKey, enabled);
    } catch (error) {
      debugPrint('DLOG THEME SAVE ERROR: $error');
    }
  }
}
