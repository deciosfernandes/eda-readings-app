import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_models.dart';

/// Service responsible for managing the user's meter reading history.
///
/// **BOLT**: This service implements a write-through cache pattern. It maintains
/// an in-memory list and a profile-based index for O(1) lookups during UI rendering.
///
/// **SENTINEL**: To prevent local data leakage, all history data is encrypted
/// at rest using `FlutterSecureStorage`.
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

  // BOLT: Cache raw maps and fully instantiated objects to avoid redundant disk I/O,
  // JSON decoding, and O(N) object creation on every UI rebuild.
  List<Map<String, dynamic>>? _cachedMaps;
  List<LocalReadingHistory>? _cachedObjects;

  // BOLT: Profile-based index using instantiated objects to achieve O(1) lookup.
  Map<String?, List<LocalReadingHistory>>? _indexedObjects;

  // Guard: ensure concurrent callers await the same in-flight load future.
  Completer<void>? _loadCompleter;

  @visibleForTesting
  void clearCache() {
    _prefs = null;
    _cachedMaps = null;
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

    // SENTINEL/BOLT: Guard the entire storage read in try/finally so the
    // Completer always resolves. PlatformException from the Android Keystore
    // (e.g. signing-key change after a Play Store re-sign) would otherwise
    // leave _loadCompleter hanging forever → permanent splash freeze.
    try {
      // SENTINEL: Use encrypted storage for reading history to prevent data leakage.
      final secureData = await _secureStorage.read(key: keyHistory);

      if (secureData != null) {
        try {
          final List<dynamic> decoded = json.decode(secureData);
          // BOLT: Support both legacy double-encoded (List<String>) and optimized single-encoded (List<Map>) formats.
          if (decoded.isNotEmpty && decoded.first is String) {
            _cachedMaps = decoded.map((s) => json.decode(s as String) as Map<String, dynamic>).toList();
          } else {
            _cachedMaps = decoded.cast<Map<String, dynamic>>();
          }
        } catch (e) {
          _cachedMaps = [];
        }
      } else {
        // One-time migration from SharedPreferences to FlutterSecureStorage
        _prefs ??= await SharedPreferences.getInstance();
        final legacyStrings = _prefs!.getStringList(keyHistory);

        if (legacyStrings != null) {
          _cachedMaps = legacyStrings.map((s) => json.decode(s) as Map<String, dynamic>).toList();
          await _secureStorage.write(
            key: keyHistory,
            value: json.encode(_cachedMaps),
          );
          await _prefs!.remove(keyHistory);
        } else {
          _cachedMaps = [];
        }
      }
    } catch (e) {
      // SENTINEL: Undecryptable storage (corrupt keystore entry) — treat as
      // empty history. Best-effort cleanup so future writes succeed.
      _cachedMaps = [];
      try {
        await _secureStorage.delete(key: keyHistory);
      } catch (_) {
        // Best-effort delete; ignore secondary failures.
      }
    } finally {
      // BOLT: Always build the in-memory index from whatever data we have.
      for (final map in _cachedMaps ?? []) {
        try {
          final reading = LocalReadingHistory.fromJson(map);
          _cachedObjects!.add(reading);
          _indexedObjects!.putIfAbsent(reading.profileId, () => []).add(reading);
        } catch (e) {
          // Skip malformed entries
        }
      }
      // BOLT: Always complete — even on error — so callers are never suspended.
      _loadCompleter!.complete();
    }
  }

  /// Adds a single [reading] to the history and persists it.
  ///
  /// **BOLT**: The reading is prepended to the in-memory cache to ensure it
  /// appears immediately on the dashboard without a full reload.
  Future<void> addReading(LocalReadingHistory reading) async {
    await _ensureHistoryLoaded();

    // BOLT: Maintain O(1) write performance and keep all in-memory caches in sync.
    _cachedObjects!.insert(0, reading);
    _indexedObjects!
        .putIfAbsent(reading.profileId, () => [])
        .insert(0, reading);

    // BOLT: Update raw map cache and persist using single-level JSON encoding.
    _cachedMaps!.insert(0, reading.toJson());
    await _secureStorage.write(
      key: keyHistory,
      value: json.encode(_cachedMaps),
    );
  }

  /// Retrieves the reading history, optionally filtered by [profileId].
  ///
  /// **BOLT**: Uses a profile-indexed map to achieve O(1) lookup when a
  /// specific profile is requested.
  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    await _ensureHistoryLoaded();

    // BOLT: Use the profile index for O(1) lookup when a profileId is specified.
    // Returning an UnmodifiableListView to prevent external modification of the internal
    // cache while avoiding the O(N) cost of List.from().
    if (profileId != null) {
      final matches = _indexedObjects![profileId];
      return matches != null ? UnmodifiableListView(matches) : const [];
    }

    return UnmodifiableListView(_cachedObjects!);
  }

  /// Batch adds multiple [readings] to the history.
  ///
  /// **BOLT**: Performs a single atomic update to the persistent storage after
  /// updating all in-memory caches to minimize I/O overhead during large imports.
  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    await _ensureHistoryLoaded();

    // BOLT: Batch update all caches and persistent storage.
    _cachedObjects!.insertAll(0, readings);
    // BOLT: Avoid intermediate list allocation by passing the mapped iterable directly.
    _cachedMaps!.insertAll(0, readings.map((r) => r.toJson()));

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

    // BOLT: Persist data using single-level JSON encoding.
    await _secureStorage.write(
      key: keyHistory,
      value: json.encode(_cachedMaps),
    );
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(
    List<String> profileIds,
  ) async {
    await _ensureHistoryLoaded();

    if (profileIds.isEmpty) {
      return UnmodifiableListView(_cachedObjects!);
    }

    // BOLT: Optimize common case where only one profile is requested.
    // Since individual profile buckets are already chronological, we skip sorting.
    // BOLT: Return an UnmodifiableListView to avoid the O(N) cost of List.from().
    if (profileIds.length == 1) {
      final matches = _indexedObjects![profileIds[0]];
      return matches != null ? UnmodifiableListView(matches) : const [];
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
