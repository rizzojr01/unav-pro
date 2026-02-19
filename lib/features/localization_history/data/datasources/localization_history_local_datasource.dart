import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/localization_history_model.dart';

abstract class LocalizationHistoryLocalDataSource {
  Future<List<LocalizationHistoryModel>> getLocalizationHistory();
  Future<void> saveLocalizationHistory(LocalizationHistoryModel history);
  Future<void> clearHistory();
}

class LocalizationHistoryLocalDataSourceImpl
    implements LocalizationHistoryLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _historyKey = 'localization_history';

  LocalizationHistoryLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<List<LocalizationHistoryModel>> getLocalizationHistory() async {
    final jsonString = sharedPreferences.getString(_historyKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => LocalizationHistoryModel.fromJson(json))
          .toList();
    }
    return [];
  }

  @override
  Future<void> saveLocalizationHistory(LocalizationHistoryModel history) async {
    final historyList = await getLocalizationHistory();

    // Check if the destination is already in the recent history to avoid duplicates
    // We'll keep the most recent one at the top
    final existingIndex = historyList.indexWhere(
      (item) =>
          item.destinationId == history.destinationId &&
          item.building == history.building &&
          item.floor == history.floor,
    );

    if (existingIndex != -1) {
      historyList.removeAt(existingIndex);
    }

    historyList.insert(0, history);

    // Keep only the last 20 recent destinations
    if (historyList.length > 20) {
      historyList.removeRange(20, historyList.length);
    }

    final jsonString = json.encode(historyList.map((h) => h.toJson()).toList());
    await sharedPreferences.setString(_historyKey, jsonString);
  }

  @override
  Future<void> clearHistory() async {
    await sharedPreferences.remove(_historyKey);
  }
}
