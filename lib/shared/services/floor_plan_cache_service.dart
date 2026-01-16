import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache floor plan images locally
/// Caches base64 images with a key based on place_building_floor
class FloorPlanCacheService {
  final SharedPreferences _prefs;

  static const String _cacheKeyPrefix = 'floor_plan_cache_';
  static const String _cacheMetaKeyPrefix = 'floor_plan_meta_';

  FloorPlanCacheService(this._prefs);

  /// Generate a unique cache key for the given location
  String _getCacheKey(String place, String building, String floor) {
    return '$_cacheKeyPrefix${place}_${building}_$floor';
  }

  /// Generate a meta key for storing cache timestamp
  String _getMetaKey(String place, String building, String floor) {
    return '$_cacheMetaKeyPrefix${place}_${building}_$floor';
  }

  /// Get cached floor plan image as Uint8List (decoded from base64)
  /// Returns null if not cached
  Uint8List? getCachedFloorPlan({
    required String place,
    required String building,
    required String floor,
  }) {
    final cacheKey = _getCacheKey(place, building, floor);
    final base64String = _prefs.getString(cacheKey);

    if (base64String != null && base64String.isNotEmpty) {
      try {
        return base64Decode(base64String);
      } catch (e) {
        // Invalid cached data, clear it
        clearCache(place: place, building: building, floor: floor);
        return null;
      }
    }
    return null;
  }

  /// Get cached floor plan as base64 string
  /// Returns null if not cached
  String? getCachedFloorPlanBase64({
    required String place,
    required String building,
    required String floor,
  }) {
    final cacheKey = _getCacheKey(place, building, floor);
    return _prefs.getString(cacheKey);
  }

  /// Check if a floor plan is cached for the given location
  bool hasCachedFloorPlan({
    required String place,
    required String building,
    required String floor,
  }) {
    final cacheKey = _getCacheKey(place, building, floor);
    final cached = _prefs.getString(cacheKey);
    return cached != null && cached.isNotEmpty;
  }

  /// Cache a floor plan image (base64 string)
  Future<void> cacheFloorPlan({
    required String place,
    required String building,
    required String floor,
    required String base64Image,
  }) async {
    final cacheKey = _getCacheKey(place, building, floor);
    final metaKey = _getMetaKey(place, building, floor);

    await _prefs.setString(cacheKey, base64Image);
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

  /// Clear all cached floor plans
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
