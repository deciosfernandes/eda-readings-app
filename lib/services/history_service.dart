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

  // BOLT: In-memory cache for decoded JSON maps to avoid redundant disk I/O.
  // We cache Maps instead of model objects to reduce memory pressure and allow
  // for lazy filtering before expensive object instantiation.
  List<Map<String, dynamic>>? _cachedMaps;

  @visibleForTesting
  void clearCache() {
    _cachedMaps = null;
  }

  Future<List<Map<String, dynamic>>> _ensureMapsLoaded() async {
    if (_cachedMaps != null) return _cachedMaps!;

    final prefs = await SharedPreferences.getInstance();
    final historyStrings = prefs.getStringList(keyHistory) ?? [];

    // BOLT: Decode once into Maps and cache them.
    _cachedMaps = historyStrings
        .map((item) {
          try {
            return json.decode(item) as Map<String, dynamic>;
          } catch (e) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    return _cachedMaps!;
  }

  Future<void> addReading(LocalReadingHistory reading) async {
    await _ensureMapsLoaded();

    final readingJson = reading.toJson();

    // BOLT: Maintain O(1) write performance by only encoding the new reading
    // and prepending it to the persistent list, while keeping the cache in sync.
    _cachedMaps!.insert(0, readingJson);

    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    historyStrings.insert(0, json.encode(readingJson));
    await prefs.setStringList(keyHistory, historyStrings);
  }

  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    final maps = await _ensureMapsLoaded();

    // BOLT: Filter by profileId on the Map level first to avoid expensive object
    // instantiation for non-matching items, as per the 2026-02-09 journal entry.
    // While this re-instantiates matching objects on every call, the overhead
    // is negligible compared to the memory pressure of caching thousands of
    // full model objects, especially since this is called outside of build loops.
    if (profileId == null) {
      return maps.map((m) => LocalReadingHistory.fromJson(m)).toList();
    }

    return maps
        .where((m) => m['profileId'] == profileId)
        .map((m) => LocalReadingHistory.fromJson(m))
        .toList();
  }

  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    await _ensureMapsLoaded();

    final newJsons = readings.map((r) => r.toJson()).toList();

    // BOLT: Maintain efficient write path for batch additions.
    _cachedMaps!.insertAll(0, newJsons);

    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    final newStrings = newJsons.map((j) => json.encode(j)).toList();
    historyStrings.insertAll(0, newStrings);
    await prefs.setStringList(keyHistory, historyStrings);
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(
    List<String> profileIds,
  ) async {
    final maps = await _ensureMapsLoaded();

    if (profileIds.isEmpty) {
      return maps.map((m) => LocalReadingHistory.fromJson(m)).toList();
    }

    // BOLT: Use a Set for O(1) lookup during filtering, reducing complexity from O(N*M) to O(N).
    final idSet = profileIds.toSet();

    return maps
        .where((m) => m['profileId'] != null && idSet.contains(m['profileId']))
        .map((m) => LocalReadingHistory.fromJson(m))
        .toList();
  }
}
