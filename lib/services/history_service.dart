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
    final historyStrings = prefs.getStringList(keyHistory) ?? [];

    // BOLT: Use a lazy map/filter approach.
    // We decode only as much as needed to filter by profileId.
    return historyStrings
        .map((item) => json.decode(item) as Map<String, dynamic>)
        .where((map) => profileId == null || map['profileId'] == profileId)
        .map((map) => LocalReadingHistory.fromJson(map))
        .toList();
  }

  Future<void> addReadings(List<LocalReadingHistory> readings) async {
    if (readings.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];

    // Prepend all new readings (most recent first)
    final newStrings = readings.map((r) => json.encode(r.toJson())).toList();
    historyStrings.insertAll(0, newStrings);
    await prefs.setStringList(keyHistory, historyStrings);
  }

  Future<List<LocalReadingHistory>> getHistoryForProfiles(List<String> profileIds) async {
    final prefs = await SharedPreferences.getInstance();
    final historyStrings = prefs.getStringList(keyHistory) ?? [];

    // BOLT: Use a lazy map/filter approach.
    return historyStrings
        .map((item) => json.decode(item) as Map<String, dynamic>)
        .where((map) =>
            profileIds.isEmpty ||
            (map['profileId'] != null && profileIds.contains(map['profileId'])))
        .map((map) => LocalReadingHistory.fromJson(map))
        .toList();
  }
}
