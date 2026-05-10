import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_models.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();

  factory HistoryService() {
    return _instance;
  }

  HistoryService._internal();

  static const String keyHistory = 'readings_history';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // BOLT: Cache SharedPreferences instance to avoid repeated async lookups.
  SharedPreferences? _prefs;

  // BOLT: Cache raw strings and fully instantiated objects to avoid redundant disk I/O,
  // JSON decoding, and O(N) object creation on every UI rebuild.
  List<String>? _cachedStrings;
  List<LocalReadingHistory>? _cachedObjects;

  // BOLT: Profile-based index using instantiated objects to achieve O(1) lookup.
  Map<String?, List<LocalReadingHistory>>? _indexedObjects;

  // Guard: ensure concurrent callers await the same in-flight load future.
  Completer<void>? _loadCompleter;

  @visibleForTesting
  void clearCache() {
    _prefs = null;
    _cachedStrings = null;
    _cachedObjects = null;
    _indexedObjects = null;
    _loadCompleter = null;
  }

  Future<void> _ensureHistoryLoaded() async {
    if (_cachedObjects != null) return;
    if (_loadCompleter != null) return _loadCompleter!.future;

    _loadCompleter = Completer<void>();

    _cachedObjects = [];
    _indexedObjects = {};

    // SENTINEL: Use encrypted storage for reading history to prevent data leakage.
    final secureData = await _secureStorage.read(key: keyHistory);

    if (secureData != null) {
      try {
        final List<dynamic> decoded = json.decode(secureData);
        _cachedStrings = decoded.cast<String>();
      } catch (e) {
        _cachedStrings = [];
      }
    } else {
      // One-time migration from SharedPreferences to FlutterSecureStorage
      _prefs ??= await SharedPreferences.getInstance();
      _cachedStrings = _prefs!.getStringList(keyHistory);

      if (_cachedStrings != null) {
        await _secureStorage.write(
          key: keyHistory,
          value: json.encode(_cachedStrings),
        );
        await _prefs!.remove(keyHistory);
      } else {
        _cachedStrings = [];
      }
    }

    for (final item in _cachedStrings!) {
      try {
        final map = json.decode(item) as Map<String, dynamic>;
        final reading = LocalReadingHistory.fromJson(map);
        _cachedObjects!.add(reading);
        _indexedObjects!.putIfAbsent(reading.profileId, () => []).add(reading);
      } catch (e) {
        // Skip malformed entries
      }
    }

    _loadCompleter!.complete();
  }

  Future<void> addReading(LocalReadingHistory reading) async {
    await _ensureHistoryLoaded();

    // BOLT: Maintain O(1) write performance and keep all in-memory caches in sync.
    _cachedObjects!.insert(0, reading);
    _indexedObjects!
        .putIfAbsent(reading.profileId, () => [])
        .insert(0, reading);

    final encoded = json.encode(reading.toJson());
    _cachedStrings!.insert(0, encoded);
    await _secureStorage.write(
      key: keyHistory,
      value: json.encode(_cachedStrings),
    );
  }

  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    await _ensureHistoryLoaded();

    // BOLT: Use the profile index for O(1) lookup when a profileId is specified.
    // Returning a new List to prevent external modification of the internal cache.
    if (profileId != null) {
      final matches = _indexedObjects![profileId];
      return matches != null ? List.from(matches) : [];
    }

    return List.from(_cachedObjects!);
  }

  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    await _ensureHistoryLoaded();

    final newEncoded = readings.map((r) => json.encode(r.toJson())).toList();

    // BOLT: Batch update all caches and persistent storage.
    _cachedObjects!.insertAll(0, readings);
    _cachedStrings!.insertAll(0, newEncoded);

    // Group new items by profile to maintain relative order during prepending.
    final groupedByProfile = <String?, List<LocalReadingHistory>>{};
    for (final reading in readings) {
      groupedByProfile
          .putIfAbsent(reading.profileId, () => [])
          .add(reading);
    }

    groupedByProfile.forEach((pId, items) {
      _indexedObjects!.putIfAbsent(pId, () => []).insertAll(0, items);
    });

    await _secureStorage.write(
      key: keyHistory,
      value: json.encode(_cachedStrings),
    );
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(
    List<String> profileIds,
  ) async {
    await _ensureHistoryLoaded();

    if (profileIds.isEmpty) {
      return List.from(_cachedObjects!);
    }

    // BOLT: Optimize common case where only one profile is requested.
    // Since individual profile buckets are already chronological, we skip sorting.
    if (profileIds.length == 1) {
      final matches = _indexedObjects![profileIds[0]];
      return matches != null ? List.from(matches) : [];
    }

    // BOLT: Collect from indexed buckets. This is O(M) where M is the number of requested profiles.
    final result = <LocalReadingHistory>[];
    for (final id in profileIds) {
      final matches = _indexedObjects![id];
      if (matches != null) {
        result.addAll(matches);
      }
    }

    // BOLT: Maintain chronological order (newest first) by sorting.
    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }
}
