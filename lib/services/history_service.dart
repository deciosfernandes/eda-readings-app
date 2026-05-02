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

  // BOLT: Cache SharedPreferences instance to avoid repeated async lookups.
  SharedPreferences? _prefs;

  // BOLT: Cache raw strings and decoded maps to avoid redundant disk I/O and O(N) list copies.
  List<String>? _cachedStrings;
  List<Map<String, dynamic>>? _cachedMaps;

  // BOLT: Profile-based index to achieve O(1) lookup for the most common queries.
  Map<String?, List<Map<String, dynamic>>>? _indexedMaps;

  @visibleForTesting
  void clearCache() {
    _prefs = null;
    _cachedStrings = null;
    _cachedMaps = null;
    _indexedMaps = null;
  }

  Future<void> _ensureMapsLoaded() async {
    if (_cachedMaps != null) return;

    _prefs ??= await SharedPreferences.getInstance();
    _cachedStrings = _prefs!.getStringList(keyHistory) ?? [];

    _cachedMaps = [];
    _indexedMaps = {};

    for (final item in _cachedStrings!) {
      try {
        final map = json.decode(item) as Map<String, dynamic>;
        _cachedMaps!.add(map);
        final pId = map['profileId'] as String?;
        _indexedMaps!.putIfAbsent(pId, () => []).add(map);
      } catch (e) {
        // Skip malformed entries
      }
    }
  }

  Future<void> addReading(LocalReadingHistory reading) async {
    await _ensureMapsLoaded();

    final readingJson = reading.toJson();
    final pId = reading.profileId;

    // BOLT: Maintain O(1) write performance and keep all in-memory caches in sync.
    _cachedMaps!.insert(0, readingJson);
    _indexedMaps!.putIfAbsent(pId, () => []).insert(0, readingJson);

    final encoded = json.encode(readingJson);
    _cachedStrings!.insert(0, encoded);
    await _prefs!.setStringList(keyHistory, _cachedStrings!);
  }

  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    await _ensureMapsLoaded();

    // BOLT: Use the profile index for O(1) lookup when a profileId is specified.
    if (profileId != null) {
      final matches = _indexedMaps![profileId];
      if (matches == null) return [];
      return matches.map((m) => LocalReadingHistory.fromJson(m)).toList();
    }

    return _cachedMaps!.map((m) => LocalReadingHistory.fromJson(m)).toList();
  }

  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    await _ensureMapsLoaded();

    final newJsons = readings.map((r) => r.toJson()).toList();
    final newEncoded = newJsons.map((j) => json.encode(j)).toList();

    // BOLT: Batch update all caches and persistent storage.
    _cachedMaps!.insertAll(0, newJsons);
    _cachedStrings!.insertAll(0, newEncoded);

    // Group new items by profile to maintain relative order during prepending.
    final groupedByProfile = <String?, List<Map<String, dynamic>>>{};
    for (final map in newJsons) {
      final pId = map['profileId'] as String?;
      groupedByProfile.putIfAbsent(pId, () => []).add(map);
    }

    groupedByProfile.forEach((pId, items) {
      _indexedMaps!.putIfAbsent(pId, () => []).insertAll(0, items);
    });

    await _prefs!.setStringList(keyHistory, _cachedStrings!);
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(
    List<String> profileIds,
  ) async {
    await _ensureMapsLoaded();

    if (profileIds.isEmpty) {
      return _cachedMaps!.map((m) => LocalReadingHistory.fromJson(m)).toList();
    }

    // BOLT: Collect from indexed buckets. This is O(M) where M is the number of requested profiles,
    // which is significantly faster than O(N) scanning when history is large.
    final result = <Map<String, dynamic>>[];
    for (final id in profileIds) {
      final matches = _indexedMaps![id];
      if (matches != null) {
        result.addAll(matches);
      }
    }

    // BOLT: Maintain chronological order (newest first) by sorting on the ISO date strings.
    // We add a safety check for the 'date' key to prevent potential crashes.
    result.sort((a, b) {
      final dateA = a['date'] as String? ?? '';
      final dateB = b['date'] as String? ?? '';
      return dateB.compareTo(dateA);
    });

    return result.map((m) => LocalReadingHistory.fromJson(m)).toList();
  }
}
