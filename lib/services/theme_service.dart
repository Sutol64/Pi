
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService with ChangeNotifier {
  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  ThemeService(this._prefs)
      : _themeMode = _prefs.getString('themeMode') == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _prefs.setString('themeMode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }
}
