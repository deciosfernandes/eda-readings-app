import 'dart:convert';

class UserProfile {
  String name;
  String picturePath;

  UserProfile({required this.name, required this.picturePath});

  Map<String, dynamic> toJson() => {
        'name': name,
        'picturePath': picturePath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? 'User',
        picturePath: json['picturePath'] as String? ?? '',
      );
}

class ContractProfile {
  String id;
  String name;
  String cil;
  String contract;
  int iconCodePoint;

  // PALETTE: Persisted reminder state so users can manage reminders from
  // Settings without deleting/re-adding the profile.
  bool reminderEnabled;

  // ISO-8601 string (date + time) of the scheduled reminder, null when none.
  String? reminderDateTime;

  ContractProfile({
    required this.id,
    required this.name,
    required this.cil,
    required this.contract,
    this.iconCodePoint = 0xe318, // Icons.home
    this.reminderEnabled = false,
    this.reminderDateTime,
  });

  // BOLT: Derive a stable, non-colliding notification ID from the profile id
  // string. Using String.hashCode (deterministic for the same content in Dart)
  // rather than int.tryParse() ?? 0 avoids the collision where all non-numeric
  // ids map to the same notification slot.
  int get notificationId => id.hashCode.abs() % 0x7FFFFFFF;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cil': cil,
        'contract': contract,
        'iconCodePoint': iconCodePoint,
        'reminderEnabled': reminderEnabled,
        if (reminderDateTime != null) 'reminderDateTime': reminderDateTime,
      };

  factory ContractProfile.fromJson(Map<String, dynamic> json) =>
      ContractProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        cil: json['cil'] as String? ?? '',
        contract: json['contract'] as String? ?? '',
        // SENTINEL: JSON numbers may decode as double on some platforms; coerce safely.
        iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ?? 0xe318,
        // SENTINEL: Accept both bool and string-encoded bool (legacy storage).
        reminderEnabled: json['reminderEnabled'] == true ||
            json['reminderEnabled'] == 'true',
        reminderDateTime: json['reminderDateTime'] as String?,
      );
}

class AppStateData {
  UserProfile userProfile;
  List<ContractProfile> profiles;
  int activeProfileIndex;

  AppStateData({
    required this.userProfile,
    required this.profiles,
    required this.activeProfileIndex,
  });

  Map<String, dynamic> toJson() => {
        'userProfile': userProfile.toJson(),
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'activeProfileIndex': activeProfileIndex,
      };

  factory AppStateData.fromJson(Map<String, dynamic> json) {
    final profilesList = json['profiles'] as List? ?? [];
    // SENTINEL: Parse profiles defensively — a single malformed entry must not
    // prevent the rest of the state from loading (and must not propagate up to
    // SecureStorageService where it would wipe the entire app state).
    final List<ContractProfile> loadedProfiles = [];
    for (final p in profilesList) {
      try {
        loadedProfiles.add(
          ContractProfile.fromJson(p as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip malformed entries rather than propagating; visible in debugPrint
        // if needed.
      }
    }

    return AppStateData(
      userProfile: json['userProfile'] != null
          ? UserProfile.fromJson(json['userProfile'] as Map<String, dynamic>)
          : UserProfile(name: 'User', picturePath: ''),
      profiles: loadedProfiles,
      activeProfileIndex: (json['activeProfileIndex'] as num?)?.toInt() ?? 0,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory AppStateData.fromJsonString(String jsonString) =>
      AppStateData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
