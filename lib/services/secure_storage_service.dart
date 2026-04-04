import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String keyAppState = 'app_state_data';

  Future<AppStateData> getAppState() async {
    final stateStr = await _storage.read(key: keyAppState);
    if (stateStr != null) {
      try {
        return AppStateData.fromJsonString(stateStr);
      } catch (e) {
        // Fallback to default
      }
    }
    return AppStateData(
      userProfile: UserProfile(name: 'User', picturePath: ''),
      profiles: [],
      activeProfileIndex: 0,
    );
  }

  Future<void> saveAppState(AppStateData data) async {
    await _storage.write(key: keyAppState, value: data.toJsonString());
  }

  Future<void> clearAppState() async {
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
      // Return currently active profile
      if (state.activeProfileIndex >= 0 && state.activeProfileIndex < state.profiles.length) {
        final active = state.profiles[state.activeProfileIndex];
        return {'cil': active.cil, 'contract': active.contract};
      }
    }
    return null;
  }

  static const String keyTutorial = 'has_seen_tutorial';
  static const String keyReadingTutorial = 'has_seen_reading_tutorial';

  Future<bool> hasSeenTutorial() async {
    final seenStr = await _storage.read(key: keyTutorial);
    return seenStr == 'true';
  }

  Future<void> setSeenTutorial(bool flag) async {
    await _storage.write(key: keyTutorial, value: flag.toString());
  }

  Future<bool> hasSeenReadingTutorial() async {
    final seenStr = await _storage.read(key: keyReadingTutorial);
    return seenStr == 'true';
  }

  Future<void> setSeenReadingTutorial(bool flag) async {
    await _storage.write(key: keyReadingTutorial, value: flag.toString());
  }
}
