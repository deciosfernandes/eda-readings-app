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

  // BOLT: Cache SharedPreferences instance to avoid redundant platform channel calls.
  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Loads the persisted theme mode from disk.
  Future<void> loadTheme({bool forceRefresh = false}) async {
    // BOLT: Persistently load the user's theme preference from SharedPreferences
    // to ensure the UI matches their previous choice immediately upon startup.
    if (forceRefresh) _prefs = await SharedPreferences.getInstance();
    _prefs ??= await SharedPreferences.getInstance();
    final index = _prefs!.getInt(_key);
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

    // BOLT: Call notifyListeners() immediately for instant UI feedback,
    // then asynchronously persist the change to avoid blocking the main thread.
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_key, mode.index);
  }
}
