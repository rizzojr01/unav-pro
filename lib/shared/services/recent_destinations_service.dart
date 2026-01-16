import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/destination/data/models/destination_model.dart';
import '../../features/destination/domain/entities/destination_entity.dart';

/// Service to manage recently visited destinations
class RecentDestinationsService {
  final SharedPreferences _prefs;

  static const String _recentDestinationsKey = 'recent_destinations';
  static const int _maxRecentDestinations = 10;

  RecentDestinationsService(this._prefs);

  /// Get list of recent destinations (most recent first)
  List<DestinationEntity> getRecentDestinations() {
    final jsonString = _prefs.getString(_recentDestinationsKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((e) => DestinationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Invalid cached data, clear it
        clearRecentDestinations();
        return [];
      }
    }
    return [];
  }

  /// Add a destination to recent list
  /// Moves it to the top if already exists
  Future<void> addRecentDestination(DestinationEntity destination) async {
    final recentDestinations = getRecentDestinations();

    // Remove if already exists (to move to top)
    recentDestinations.removeWhere((d) => d.id == destination.id);

    // Add to the beginning
    recentDestinations.insert(0, destination);

    // Limit to max items
    final trimmed = recentDestinations.take(_maxRecentDestinations).toList();

    // Save
    final jsonList = trimmed
        .map((e) => DestinationModel.fromEntity(e).toJson())
        .toList();
    final jsonString = jsonEncode(jsonList);

    await _prefs.setString(_recentDestinationsKey, jsonString);
  }

  /// Check if there are any recent destinations
  bool hasRecentDestinations() {
    return getRecentDestinations().isNotEmpty;
  }

  /// Clear all recent destinations
  Future<void> clearRecentDestinations() async {
    await _prefs.remove(_recentDestinationsKey);
  }
}
