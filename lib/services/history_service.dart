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

  // BOLT: In-memory cache to avoid redundant SharedPreferences access and JSON decoding.
  List<LocalReadingHistory>? _cachedHistory;

  @visibleForTesting
  void clearCache() {
    _cachedHistory = null;
  }

  Future<List<LocalReadingHistory>> _ensureLoaded() async {
    if (_cachedHistory != null) return _cachedHistory!;

    final prefs = await SharedPreferences.getInstance();
    final historyStrings = prefs.getStringList(keyHistory) ?? [];

    // BOLT: Decode once and cache the resulting objects to improve performance on subsequent reads.
    _cachedHistory = historyStrings
        .map((item) {
          try {
            return LocalReadingHistory.fromJson(
              json.decode(item) as Map<String, dynamic>,
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<LocalReadingHistory>()
        .toList();

    return _cachedHistory!;
  }

  Future<void> addReading(LocalReadingHistory reading) async {
    await _ensureLoaded();

    // BOLT: Maintain O(1) write performance by only encoding the new reading
    // and prepending it to the persistent list, while keeping the cache in sync.
    _cachedHistory!.insert(0, reading);

    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    historyStrings.insert(0, json.encode(reading.toJson()));
    await prefs.setStringList(keyHistory, historyStrings);
  }

  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    final history = await _ensureLoaded();

    if (profileId == null) return List.from(history);

    return history.where((r) => r.profileId == profileId).toList();
  }

  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    await _ensureLoaded();

    // Update cache
    _cachedHistory!.insertAll(0, readings);

    // BOLT: Restoring efficient write path for batch additions.
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    final newStrings = readings.map((r) => json.encode(r.toJson())).toList();
    historyStrings.insertAll(0, newStrings);
    await prefs.setStringList(keyHistory, historyStrings);
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(
    List<String> profileIds,
  ) async {
    final history = await _ensureLoaded();

    if (profileIds.isEmpty) return List.from(history);

    return history
        .where((r) => r.profileId != null && profileIds.contains(r.profileId))
        .toList();
  }
}
