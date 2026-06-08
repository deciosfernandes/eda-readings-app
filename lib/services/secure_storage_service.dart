import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

/// Service for managing sensitive application state and credentials.
///
/// **BOLT**: Caches the `AppStateData` and tutorial flags in-memory to prevent
/// redundant asynchronous platform channel calls during the build cycle.
///
/// **SENTINEL**: Uses `FlutterSecureStorage` to ensure that all data, including
/// profile credentials and local history pointers, are encrypted at rest.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String keyAppState = 'app_state_data';

  // BOLT: In-memory cache for AppStateData to avoid redundant asynchronous storage reads.
  @visibleForTesting
  AppStateData? cachedState;

  /// Retrieves the full application state.
  ///
  /// **BOLT**: Returns the `cachedState` if already loaded, avoiding disk I/O.
  Future<AppStateData> getAppState() async {
    // BOLT: Return cached state if available to improve performance.
    if (cachedState != null) return cachedState!;

    try {
      final stateStr = await _storage.read(key: keyAppState);
      if (stateStr != null) {
        cachedState = AppStateData.fromJsonString(stateStr);
        return cachedState!;
      }
    } on PlatformException catch (e) {
      // SENTINEL: Undecryptable storage (corrupt keystore entry, e.g. signing-key
      // change via Play App Signing). Delete so future writes succeed.
      debugPrint('SecureStorageService: undecryptable storage, clearing. $e');
      try {
        await _storage.delete(key: keyAppState);
      } catch (_) {
        // Best-effort delete; ignore secondary failures.
      }
    } on FormatException catch (e) {
      // SENTINEL: Corrupt or schema-changed JSON. Delete so future writes succeed.
      debugPrint('SecureStorageService: corrupt app state JSON, clearing. $e');
      try {
        await _storage.delete(key: keyAppState);
      } catch (_) {
        // Best-effort delete; ignore secondary failures.
      }
    } catch (e) {
      // Transient error (e.g. keystore temporarily unavailable). Do NOT delete
      // — the data may still be intact. Fall through to the default below.
      debugPrint('SecureStorageService: transient read error, using default. $e');
    }

    cachedState = AppStateData(
      userProfile: UserProfile(name: 'User', picturePath: ''),
      profiles: [],
      activeProfileIndex: 0,
    );
    return cachedState!;
  }

  /// Persists the [data] to secure storage and updates the in-memory cache.
  ///
  /// **SENTINEL**: Writes to storage FIRST so that a write failure does not
  /// leave the cache ahead of disk (no phantom saves).
  /// **SENTINEL**: Caches a decoded copy so the caller's mutable object cannot
  /// silently mutate the in-memory state.
  Future<void> saveAppState(AppStateData data) async {
    final jsonString = data.toJsonString();
    // BOLT/SENTINEL: Persist first; only update cache when the write succeeds.
    await _storage.write(key: keyAppState, value: jsonString);
    // SENTINEL: Store a decoded copy, not the caller's reference, so external
    // mutations to `data` do not silently affect the cached state.
    cachedState = AppStateData.fromJsonString(jsonString);
  }

  Future<void> clearAppState() async {
    // BOLT: Invalidate cache when clearing storage.
    cachedState = null;
    // BOLT: Also clear tutorial-flag caches so they are re-read after a reset.
    _cachedHasSeenTutorial = null;
    _cachedHasSeenReadingTutorial = null;
    await _storage.delete(key: keyAppState);
  }

  // Helper method for older compatibility where login screen directly uses CIL/Contract for First Profile
  Future<void> initFirstProfile(String name, String cil, String contract) async {
    final state = await getAppState();

    state.profiles.add(ContractProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      cil: cil,
      contract: contract,
    ));

    state.activeProfileIndex = state.profiles.length - 1;
    await saveAppState(state);
  }

  Future<Map<String, String>?> getCredentials() async {
    final state = await getAppState();
    if (state.profiles.isNotEmpty) {
      // BOLT/SENTINEL: Clamp the index in case it fell out of range (e.g. after
      // deleting the active profile without updating the index).
      final clampedIndex = state.activeProfileIndex.clamp(
        0,
        state.profiles.length - 1,
      );
      if (state.activeProfileIndex != clampedIndex) {
        // Silently repair the stale index.
        state.activeProfileIndex = clampedIndex;
        try {
          await saveAppState(state);
        } catch (_) {
          // Best-effort repair; do not block credential retrieval.
        }
      }
      final active = state.profiles[clampedIndex];
      return {'cil': active.cil, 'contract': active.contract};
    }
    return null;
  }

  static const String keyTutorial = 'has_seen_tutorial';
  static const String keyReadingTutorial = 'has_seen_reading_tutorial';

  // BOLT: In-memory cache for tutorial flags to avoid redundant platform channel reads.
  bool? _cachedHasSeenTutorial;
  bool? _cachedHasSeenReadingTutorial;

  Future<bool> hasSeenTutorial() async {
    if (_cachedHasSeenTutorial != null) return _cachedHasSeenTutorial!;
    final seenStr = await _storage.read(key: keyTutorial);
    _cachedHasSeenTutorial = seenStr == 'true';
    return _cachedHasSeenTutorial!;
  }

  Future<void> setSeenTutorial(bool flag) async {
    if (_cachedHasSeenTutorial == flag) return;
    await _storage.write(key: keyTutorial, value: flag.toString());
    _cachedHasSeenTutorial = flag;
  }

  Future<bool> hasSeenReadingTutorial() async {
    if (_cachedHasSeenReadingTutorial != null) {
      return _cachedHasSeenReadingTutorial!;
    }
    final seenStr = await _storage.read(key: keyReadingTutorial);
    _cachedHasSeenReadingTutorial = seenStr == 'true';
    return _cachedHasSeenReadingTutorial!;
  }

  Future<void> setSeenReadingTutorial(bool flag) async {
    if (_cachedHasSeenReadingTutorial == flag) return;
    await _storage.write(key: keyReadingTutorial, value: flag.toString());
    _cachedHasSeenReadingTutorial = flag;
  }
}
