import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_models.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();

  factory HistoryService() {
    return _instance;
  }

  HistoryService._internal();

  static const String keyHistory = 'readings_history';

  // BOLT: In-memory cache for decoded history to avoid redundant disk I/O and JSON decoding.
  List<LocalReadingHistory>? _cachedHistory;

  @visibleForTesting
  void clearCache() {
    _cachedHistory = null;
  }

  Future<void> addReading(LocalReadingHistory reading) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];

    // Add new prepended
    historyStrings.insert(0, json.encode(reading.toJson()));
    await prefs.setStringList(keyHistory, historyStrings);

    // BOLT: Update cache if it exists.
    if (_cachedHistory != null) {
      _cachedHistory!.insert(0, reading);
    }
  }

  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    // BOLT: Return from cache if available.
    if (_cachedHistory == null) {
      final prefs = await SharedPreferences.getInstance();
      final historyStrings = prefs.getStringList(keyHistory) ?? [];

      // BOLT: Decode and cache the entire history.
      _cachedHistory = historyStrings
          .map((item) => LocalReadingHistory.fromJson(json.decode(item) as Map<String, dynamic>))
          .toList();
    }

    if (profileId == null) return List.from(_cachedHistory!);

    return _cachedHistory!
        .where((item) => item.profileId == profileId)
        .toList();
  }

  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];

    // Prepend all new readings (most recent first)
    final newStrings = readings.map((r) => json.encode(r.toJson())).toList();
    historyStrings.insertAll(0, newStrings);
    await prefs.setStringList(keyHistory, historyStrings);

    // BOLT: Update cache if it exists.
    if (_cachedHistory != null) {
      _cachedHistory!.insertAll(0, readings);
    }
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(List<String> profileIds) async {
    // BOLT: Use getHistory to ensure cache is populated and then filter.
    final history = await getHistory();

    if (profileIds.isEmpty) return history;

    return history
        .where((item) => item.profileId != null && profileIds.contains(item.profileId))
        .toList();
  }
}
