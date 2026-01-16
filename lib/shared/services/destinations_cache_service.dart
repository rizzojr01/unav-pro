import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/destination/data/models/destination_model.dart';
import '../../features/destination/domain/entities/destination_entity.dart';

/// Service to cache destinations list locally
/// Caches destinations with a key based on place_building_floor
class DestinationsCacheService {
  final SharedPreferences _prefs;

  static const String _cacheKeyPrefix = 'destinations_cache_';
  static const String _cacheMetaKeyPrefix = 'destinations_meta_';

  DestinationsCacheService(this._prefs);

  /// Generate a unique cache key for the given location
  String _getCacheKey(String place, String building, String floor) {
    return '$_cacheKeyPrefix${place}_${building}_$floor';
  }

  /// Generate a meta key for storing cache timestamp
  String _getMetaKey(String place, String building, String floor) {
    return '$_cacheMetaKeyPrefix${place}_${building}_$floor';
  }

  /// Get cached destinations list
  /// Returns null if not cached
  List<DestinationEntity>? getCachedDestinations({
    required String place,
    required String building,
    required String floor,
  }) {
    final cacheKey = _getCacheKey(place, building, floor);
    final jsonString = _prefs.getString(cacheKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((e) => DestinationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Invalid cached data, clear it
        clearCache(place: place, building: building, floor: floor);
        return null;
      }
    }
    return null;
  }

  /// Check if destinations are cached for the given location
  bool hasCachedDestinations({
    required String place,
    required String building,
    required String floor,
  }) {
    final cacheKey = _getCacheKey(place, building, floor);
    final cached = _prefs.getString(cacheKey);
    return cached != null && cached.isNotEmpty;
  }

  /// Cache destinations list
  Future<void> cacheDestinations({
    required String place,
    required String building,
    required String floor,
    required List<DestinationEntity> destinations,
  }) async {
    final cacheKey = _getCacheKey(place, building, floor);
    final metaKey = _getMetaKey(place, building, floor);

    // Convert to JSON list
    final jsonList = destinations
        .map((e) => DestinationModel.fromEntity(e).toJson())
        .toList();
    final jsonString = jsonEncode(jsonList);

    await _prefs.setString(cacheKey, jsonString);
    await _prefs.setInt(metaKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear cache for a specific location
  Future<void> clearCache({
    required String place,
    required String building,
    required String floor,
  }) async {
    final cacheKey = _getCacheKey(place, building, floor);
    final metaKey = _getMetaKey(place, building, floor);

    await _prefs.remove(cacheKey);
    await _prefs.remove(metaKey);
  }

  /// Clear all cached destinations
  Future<void> clearAllCache() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_cacheMetaKeyPrefix)) {
        await _prefs.remove(key);
      }
    }
  }

  /// Get cache timestamp for a specific location
  DateTime? getCacheTimestamp({
    required String place,
    required String building,
    required String floor,
  }) {
    final metaKey = _getMetaKey(place, building, floor);
    final timestamp = _prefs.getInt(metaKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Check if cache is stale (older than specified duration)
  bool isCacheStale({
    required String place,
    required String building,
    required String floor,
    Duration maxAge = const Duration(days: 7),
  }) {
    final timestamp = getCacheTimestamp(
      place: place,
      building: building,
      floor: floor,
    );
    if (timestamp == null) return true;

    return DateTime.now().difference(timestamp) > maxAge;
  }
}
