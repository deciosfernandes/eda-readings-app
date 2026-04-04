import 'package:flutter_test/flutter_test.dart';
import 'package:eda_app/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('toJson serializes name and picturePath', () {
      final profile = UserProfile(name: 'João Silva', picturePath: '/images/avatar.png');
      final json = profile.toJson();

      expect(json['name'], 'João Silva');
      expect(json['picturePath'], '/images/avatar.png');
    });

    test('fromJson deserializes name and picturePath', () {
      final json = {'name': 'Maria', 'picturePath': '/path/img.jpg'};
      final profile = UserProfile.fromJson(json);

      expect(profile.name, 'Maria');
      expect(profile.picturePath, '/path/img.jpg');
    });

    test('fromJson falls back to defaults for missing fields', () {
      final profile = UserProfile.fromJson(<String, dynamic>{});

      expect(profile.name, 'User');
      expect(profile.picturePath, '');
    });

    test('toJson / fromJson round-trip', () {
      final original = UserProfile(name: 'Test User', picturePath: '/tmp/pic.png');
      final restored = UserProfile.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.picturePath, original.picturePath);
    });
  });

  group('ContractProfile', () {
    test('constructor defaults iconCodePoint to Icons.home code point', () {
      final profile = ContractProfile(
        id: 'id1',
        name: 'Home',
        cil: 'CIL123',
        contract: 'C001',
      );

      expect(profile.iconCodePoint, 0xe318);
    });

    test('toJson serializes all fields', () {
      final profile = ContractProfile(
        id: 'id1',
        name: 'Office',
        cil: 'CIL456',
        contract: 'C002',
        iconCodePoint: 0xe3ab,
      );

      final json = profile.toJson();

      expect(json['id'], 'id1');
      expect(json['name'], 'Office');
      expect(json['cil'], 'CIL456');
      expect(json['contract'], 'C002');
      expect(json['iconCodePoint'], 0xe3ab);
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'id': 'id2',
        'name': 'Warehouse',
        'cil': 'CIL789',
        'contract': 'C003',
        'iconCodePoint': 0xe1b0,
      };

      final profile = ContractProfile.fromJson(json);

      expect(profile.id, 'id2');
      expect(profile.name, 'Warehouse');
      expect(profile.cil, 'CIL789');
      expect(profile.contract, 'C003');
      expect(profile.iconCodePoint, 0xe1b0);
    });

    test('fromJson defaults iconCodePoint when missing', () {
      final json = {
        'id': 'id3',
        'name': 'Shop',
        'cil': 'CIL000',
        'contract': 'C004',
      };

      final profile = ContractProfile.fromJson(json);

      expect(profile.iconCodePoint, 0xe318);
    });

    test('toJson / fromJson round-trip', () {
      final original = ContractProfile(
        id: 'abc',
        name: 'Flat',
        cil: 'PT001',
        contract: 'X100',
        iconCodePoint: 0xe2f0,
      );

      final restored = ContractProfile.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.cil, original.cil);
      expect(restored.contract, original.contract);
      expect(restored.iconCodePoint, original.iconCodePoint);
    });
  });

  group('AppStateData', () {
    test('constructor stores provided values', () {
      final user = UserProfile(name: 'Alice', picturePath: '');
      final profiles = [
        ContractProfile(id: 'p1', name: 'Home', cil: 'CIL1', contract: 'C1'),
      ];
      final state = AppStateData(
        userProfile: user,
        profiles: profiles,
        activeProfileIndex: 0,
      );

      expect(state.userProfile.name, 'Alice');
      expect(state.profiles.length, 1);
      expect(state.activeProfileIndex, 0);
    });

    test('toJson serializes userProfile, profiles and activeProfileIndex', () {
      final state = AppStateData(
        userProfile: UserProfile(name: 'Bob', picturePath: '/img.png'),
        profiles: [
          ContractProfile(id: 'p1', name: 'Place', cil: 'CIL1', contract: 'C1'),
        ],
        activeProfileIndex: 0,
      );

      final json = state.toJson();

      expect(json['userProfile']['name'], 'Bob');
      expect((json['profiles'] as List).length, 1);
      expect(json['activeProfileIndex'], 0);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'userProfile': {'name': 'Charlie', 'picturePath': ''},
        'profiles': [
          {
            'id': 'p1',
            'name': 'Home',
            'cil': 'CIL1',
            'contract': 'C1',
            'iconCodePoint': 0xe318,
          }
        ],
        'activeProfileIndex': 0,
      };

      final state = AppStateData.fromJson(json);

      expect(state.userProfile.name, 'Charlie');
      expect(state.profiles.length, 1);
      expect(state.profiles.first.name, 'Home');
      expect(state.activeProfileIndex, 0);
    });

    test('fromJson handles missing userProfile gracefully', () {
      final json = {
        'profiles': <dynamic>[],
        'activeProfileIndex': 0,
      };

      final state = AppStateData.fromJson(json);

      expect(state.userProfile.name, 'User');
      expect(state.userProfile.picturePath, '');
    });

    test('fromJson defaults activeProfileIndex to 0 when missing', () {
      final json = {
        'userProfile': {'name': 'User', 'picturePath': ''},
        'profiles': <dynamic>[],
      };

      final state = AppStateData.fromJson(json);

      expect(state.activeProfileIndex, 0);
    });

    test('fromJson handles empty profiles list', () {
      final json = {
        'userProfile': {'name': 'User', 'picturePath': ''},
        'profiles': <dynamic>[],
        'activeProfileIndex': 0,
      };

      final state = AppStateData.fromJson(json);

      expect(state.profiles, isEmpty);
    });

    test('toJsonString / fromJsonString round-trip', () {
      final original = AppStateData(
        userProfile: UserProfile(name: 'Diana', picturePath: '/d.png'),
        profiles: [
          ContractProfile(id: 'x1', name: 'Studio', cil: 'C99', contract: 'X99'),
        ],
        activeProfileIndex: 0,
      );

      final jsonString = original.toJsonString();
      final restored = AppStateData.fromJsonString(jsonString);

      expect(restored.userProfile.name, 'Diana');
      expect(restored.profiles.length, 1);
      expect(restored.profiles.first.cil, 'C99');
      expect(restored.activeProfileIndex, 0);
    });

    test('toJson / fromJson full round-trip with multiple profiles', () {
      final original = AppStateData(
        userProfile: UserProfile(name: 'Eve', picturePath: ''),
        profiles: [
          ContractProfile(id: 'a', name: 'A', cil: 'CA', contract: 'XA'),
          ContractProfile(id: 'b', name: 'B', cil: 'CB', contract: 'XB', iconCodePoint: 0xe0af),
        ],
        activeProfileIndex: 1,
      );

      final restored = AppStateData.fromJson(original.toJson());

      expect(restored.profiles.length, 2);
      expect(restored.profiles[1].name, 'B');
      expect(restored.profiles[1].iconCodePoint, 0xe0af);
      expect(restored.activeProfileIndex, 1);
    });
  });
}
