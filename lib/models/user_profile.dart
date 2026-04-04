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

  ContractProfile({
    required this.id,
    required this.name,
    required this.cil,
    required this.contract,
    this.iconCodePoint = 0xe318, // Icons.home
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cil': cil,
        'contract': contract,
        'iconCodePoint': iconCodePoint,
      };

  factory ContractProfile.fromJson(Map<String, dynamic> json) =>
      ContractProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        cil: json['cil'] as String,
        contract: json['contract'] as String,
        iconCodePoint: json['iconCodePoint'] as int? ?? 0xe318,
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
    var profilesList = json['profiles'] as List? ?? [];
    List<ContractProfile> loadedProfiles = profilesList
        .map((p) => ContractProfile.fromJson(p as Map<String, dynamic>))
        .toList();

    return AppStateData(
      userProfile: json['userProfile'] != null 
          ? UserProfile.fromJson(json['userProfile'] as Map<String, dynamic>) 
          : UserProfile(name: 'User', picturePath: ''),
      profiles: loadedProfiles,
      activeProfileIndex: json['activeProfileIndex'] as int? ?? 0,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory AppStateData.fromJsonString(String jsonString) =>
      AppStateData.fromJson(jsonDecode(jsonString));
}
