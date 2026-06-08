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
  ///
  /// [forceRefresh] forces a new `SharedPreferences.getInstance()` call. This
  /// is a no-op in production (the platform returns the same cached instance)
  /// but is used in tests to pick up fresh `setMockInitialValues()` values when
  /// the singleton's `_prefs` is already set.
  Future<void> loadTheme({bool forceRefresh = false}) async {
    if (forceRefresh) _prefs = null;
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
  ///
  /// **BOLT**: Notifies listeners immediately for instant UI feedback, then
  /// persists asynchronously. On persistence failure the in-memory state is
  /// reverted so the next launch restores the correct theme.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // BOLT: Notify immediately for instant UI feedback.
    notifyListeners();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_key, mode.index);
    } catch (e) {
      // SENTINEL: Revert in-memory state on persistence failure so the next
      // launch does not silently load a different theme than was shown.
      debugPrint('ThemeService: failed to persist theme: $e');
      final savedIndex = _prefs?.getInt(_key);
      _themeMode = (savedIndex != null &&
              savedIndex >= 0 &&
              savedIndex < ThemeMode.values.length)
          ? ThemeMode.values[savedIndex]
          : ThemeMode.system;
      notifyListeners();
    }
  }
}
