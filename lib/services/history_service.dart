import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_models.dart';

class HistoryService {
  static const String keyHistory = 'readings_history';

  Future<void> addReading(LocalReadingHistory reading) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    
    // Add new prepended
    historyStrings.insert(0, json.encode(reading.toJson()));
    await prefs.setStringList(keyHistory, historyStrings);
  }

  Future<List<LocalReadingHistory>> getHistory({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    
    final all = historyStrings.map((item) {
      return LocalReadingHistory.fromJson(json.decode(item));
    }).toList();

    if (profileId == null) return all;
    return all.where((r) => r.profileId == profileId).toList();
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(List<String> profileIds) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];

    final all = historyStrings.map((item) {
      return LocalReadingHistory.fromJson(json.decode(item));
    }).toList();

    if (profileIds.isEmpty) return all;
    return all.where((r) => r.profileId != null && profileIds.contains(r.profileId)).toList();
  }
}
