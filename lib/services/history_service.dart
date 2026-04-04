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

  Future<List<LocalReadingHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList(keyHistory) ?? [];
    
    return historyStrings.map((item) {
      return LocalReadingHistory.fromJson(json.decode(item));
    }).toList();
  }
}
