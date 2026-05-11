import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the application's visual theme.
///
/// **BOLT**: Utilizes `SharedPreferences` to persist the user's `ThemeMode` selection,
/// ensuring visual consistency across application sessions.
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() => _instance;

  ThemeService._internal();

  static const String _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Loads the persisted theme mode from disk.
  Future<void> loadTheme() async {
    // BOLT: Persistently load the user's theme preference from SharedPreferences
    // to ensure the UI matches their previous choice immediately upon startup.
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index != null && index >= 0 && index < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[index];
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Updates the application's theme mode and persists the change.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // BOLT: Asynchronously persist the theme mode change to disk while
    // notifying listeners to provide an immediate UI update.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
    notifyListeners();
  }
}
