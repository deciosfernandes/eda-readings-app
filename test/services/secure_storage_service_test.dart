import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eda_app/models/user_profile.dart';
import 'package:eda_app/services/secure_storage_service.dart';

// Mock FlutterSecureStorage by intercepting its platform channel.
void _setupSecureStorageMock(Map<String, String?> storage) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      switch (call.method) {
        case 'write':
          storage[call.arguments['key'] as String] =
              call.arguments['value'] as String?;
          return null;
        case 'read':
          return storage[call.arguments['key'] as String];
        case 'delete':
          storage.remove(call.arguments['key'] as String);
          return null;
        case 'deleteAll':
          storage.clear();
          return null;
        case 'readAll':
          return Map<String, String>.fromEntries(
            storage.entries
                .where((e) => e.value != null)
                .map((e) => MapEntry(e.key, e.value!)),
          );
        case 'containsKey':
          return storage.containsKey(call.arguments['key'] as String);
        default:
          return null;
      }
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String?> mockStorage;
  // SecureStorageService is a singleton; we reset the backing store via
  // the mock channel handler between tests.
  final service = SecureStorageService();

  setUp(() {
    mockStorage = {};
    _setupSecureStorageMock(mockStorage);
    // BOLT: Clear cache between tests as SecureStorageService is a singleton.
    service.cachedState = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('SecureStorageService.getAppState', () {
    test('returns default AppStateData when storage is empty', () async {
      final state = await service.getAppState();

      expect(state.userProfile.name, 'User');
      expect(state.userProfile.picturePath, '');
      expect(state.profiles, isEmpty);
      expect(state.activeProfileIndex, 0);
    });

    test('returns stored AppStateData when data exists', () async {
      final saved = AppStateData(
        userProfile: UserProfile(name: 'Alice', picturePath: '/img.png'),
        profiles: [
          ContractProfile(id: 'p1', name: 'Home', cil: 'CIL1', contract: 'C1'),
        ],
        activeProfileIndex: 0,
      );
      await service.saveAppState(saved);

      final loaded = await service.getAppState();

      expect(loaded.userProfile.name, 'Alice');
      expect(loaded.profiles.length, 1);
      expect(loaded.profiles.first.cil, 'CIL1');
    });

    test('returns default when stored JSON is invalid', () async {
      mockStorage[SecureStorageService.keyAppState] = 'not_valid_json{{{';

      final state = await service.getAppState();

      expect(state.userProfile.name, 'User');
      expect(state.profiles, isEmpty);
    });
  });

  group('SecureStorageService.saveAppState', () {
    test('persists app state and can be retrieved', () async {
      final state = AppStateData(
        userProfile: UserProfile(name: 'Bob', picturePath: ''),
        profiles: [],
        activeProfileIndex: 0,
      );

      await service.saveAppState(state);

      expect(mockStorage.containsKey(SecureStorageService.keyAppState), isTrue);
      final loaded = await service.getAppState();
      expect(loaded.userProfile.name, 'Bob');
    });
  });

  group('SecureStorageService.clearAppState', () {
    test('removes the stored app state', () async {
      await service.saveAppState(AppStateData(
        userProfile: UserProfile(name: 'Carol', picturePath: ''),
        profiles: [],
        activeProfileIndex: 0,
      ));

      await service.clearAppState();

      final loaded = await service.getAppState();
      expect(loaded.userProfile.name, 'User');
    });
  });

  group('SecureStorageService.initFirstProfile', () {
    test('adds first profile to an empty state', () async {
      await service.initFirstProfile('Home', 'CIL_001', 'CON_001');

      final state = await service.getAppState();
      expect(state.profiles.length, 1);
      expect(state.profiles.first.name, 'Home');
      expect(state.profiles.first.cil, 'CIL_001');
      expect(state.profiles.first.contract, 'CON_001');
    });

    test('appends profile to existing profiles', () async {
      final initial = AppStateData(
        userProfile: UserProfile(name: 'User', picturePath: ''),
        profiles: [
          ContractProfile(id: 'existing', name: 'Old', cil: 'C0', contract: 'X0'),
        ],
        activeProfileIndex: 0,
      );
      await service.saveAppState(initial);

      await service.initFirstProfile('New Place', 'CIL_NEW', 'CON_NEW');

      final state = await service.getAppState();
      expect(state.profiles.length, 2);
      expect(state.profiles.last.name, 'New Place');
    });
  });

  group('SecureStorageService.getCredentials', () {
    test('returns null when no profiles exist', () async {
      final credentials = await service.getCredentials();
      expect(credentials, isNull);
    });

    test('returns cil and contract for active profile', () async {
      await service.saveAppState(AppStateData(
        userProfile: UserProfile(name: 'User', picturePath: ''),
        profiles: [
          ContractProfile(id: 'p1', name: 'Home', cil: 'MYCIL', contract: 'MYCON'),
        ],
        activeProfileIndex: 0,
      ));

      final credentials = await service.getCredentials();

      expect(credentials, isNotNull);
      expect(credentials!['cil'], 'MYCIL');
      expect(credentials['contract'], 'MYCON');
    });

    test('returns active profile when index points to second profile', () async {
      await service.saveAppState(AppStateData(
        userProfile: UserProfile(name: 'User', picturePath: ''),
        profiles: [
          ContractProfile(id: 'p1', name: 'Home', cil: 'CIL1', contract: 'C1'),
          ContractProfile(id: 'p2', name: 'Office', cil: 'CIL2', contract: 'C2'),
        ],
        activeProfileIndex: 1,
      ));

      final credentials = await service.getCredentials();

      expect(credentials!['cil'], 'CIL2');
      expect(credentials['contract'], 'C2');
    });

    test('returns null when activeProfileIndex is out of range', () async {
      await service.saveAppState(AppStateData(
        userProfile: UserProfile(name: 'User', picturePath: ''),
        profiles: [
          ContractProfile(id: 'p1', name: 'Home', cil: 'CIL1', contract: 'C1'),
        ],
        activeProfileIndex: 5,
      ));

      final credentials = await service.getCredentials();
      expect(credentials, isNull);
    });
  });

  group('SecureStorageService tutorial flags', () {
    test('hasSeenTutorial returns false initially', () async {
      expect(await service.hasSeenTutorial(), isFalse);
    });

    test('setSeenTutorial(true) causes hasSeenTutorial to return true', () async {
      await service.setSeenTutorial(true);
      expect(await service.hasSeenTutorial(), isTrue);
    });

    test('setSeenTutorial(false) causes hasSeenTutorial to return false', () async {
      await service.setSeenTutorial(true);
      await service.setSeenTutorial(false);
      expect(await service.hasSeenTutorial(), isFalse);
    });

    test('hasSeenReadingTutorial returns false initially', () async {
      expect(await service.hasSeenReadingTutorial(), isFalse);
    });

    test('setSeenReadingTutorial(true) causes hasSeenReadingTutorial to return true', () async {
      await service.setSeenReadingTutorial(true);
      expect(await service.hasSeenReadingTutorial(), isTrue);
    });

    test('setSeenReadingTutorial(false) causes hasSeenReadingTutorial to return false', () async {
      await service.setSeenReadingTutorial(true);
      await service.setSeenReadingTutorial(false);
      expect(await service.hasSeenReadingTutorial(), isFalse);
    });
  });
}
