import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache floor plan images locally using the file system.
/// Keeps metadata in SharedPreferences but actual image data in files.
class FloorPlanCacheService {
  final SharedPreferences _prefs;
  Directory? _floorPlanDir;

  static const String _cacheStatusKeyPrefix = 'fp_status_';
  static const String _cacheMetaKeyPrefix = 'floor_plan_meta_';

  FloorPlanCacheService(this._prefs);

  /// Ensure the floor plan directory exists
  Future<Directory> _getDir() async {
    if (_floorPlanDir != null) return _floorPlanDir!;
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/floor_plans');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _floorPlanDir = dir;
    return dir;
  }

  /// Generate a unique filename for the given location
  String _getFileName(String place, String building, String floor) {
    return 'fp_${place}_${building}_$floor.png';
  }

  /// Generate a status key for SharedPreferences
  String _getStatusKey(String place, String building, String floor) {
    return '$_cacheStatusKeyPrefix${place}_${building}_$floor';
  }

  /// Generate a meta key for storing cache timestamp
  String _getMetaKey(String place, String building, String floor) {
    return '$_cacheMetaKeyPrefix${place}_${building}_$floor';
  }

  /// Get cached floor plan image as Uint8List
  /// Returns null if not cached or file missing
  Future<Uint8List?> getCachedFloorPlan({
    required String place,
    required String building,
    required String floor,
  }) async {
    if (!hasCachedFloorPlan(place: place, building: building, floor: floor)) {
      return null;
    }

    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_getFileName(place, building, floor)}');
      if (await file.exists()) {
        return await file.readAsBytes();
      } else {
        // Status said it exists but file is gone; sync status
        await _clearStatus(place: place, building: building, floor: floor);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Get cached floor plan as base64 string
  /// Returns null if not cached
  Future<String?> getCachedFloorPlanBase64({
    required String place,
    required String building,
    required String floor,
  }) async {
    final bytes = await getCachedFloorPlan(
      place: place,
      building: building,
      floor: floor,
    );
    if (bytes == null) return null;
    return base64Encode(bytes);
  }

  /// Check if a floor plan is cached for the given location (Synchronous)
  bool hasCachedFloorPlan({
    required String place,
    required String building,
    required String floor,
  }) {
    final statusKey = _getStatusKey(place, building, floor);
    return _prefs.getBool(statusKey) ?? false;
  }

  /// Cache a floor plan image
  Future<void> cacheFloorPlan({
    required String place,
    required String building,
    required String floor,
    required String base64Image,
  }) async {
    try {
      final bytes = base64Decode(base64Image.trim());
      await cacheFloorPlanBytes(
        place: place,
        building: building,
        floor: floor,
        bytes: bytes,
      );
    } catch (e) {
      // Invalid base64
    }
  }

  /// Cache floor plan bytes directly
  Future<void> cacheFloorPlanBytes({
    required String place,
    required String building,
    required String floor,
    required Uint8List bytes,
  }) async {
    final dir = await _getDir();
    final file = File('${dir.path}/${_getFileName(place, building, floor)}');
    await file.writeAsBytes(bytes);

    final statusKey = _getStatusKey(place, building, floor);
    final metaKey = _getMetaKey(place, building, floor);

    await _prefs.setBool(statusKey, true);
    await _prefs.setInt(metaKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear status helper
  Future<void> _clearStatus({
    required String place,
    required String building,
    required String floor,
  }) async {
    await _prefs.remove(_getStatusKey(place, building, floor));
    await _prefs.remove(_getMetaKey(place, building, floor));
  }

  /// Clear cache for a specific location
  Future<void> clearCache({
    required String place,
    required String building,
    required String floor,
  }) async {
    await _clearStatus(place: place, building: building, floor: floor);
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/${_getFileName(place, building, floor)}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Clear all cached floor plans for an entire building
  Future<void> clearCacheForBuilding({
    required String place,
    required String building,
  }) async {
    final statusPrefix = '${_cacheStatusKeyPrefix}${place}_${building}_';
    final metaPrefix = '${_cacheMetaKeyPrefix}${place}_${building}_';
    final filePrefix = 'fp_${place}_${building}_';

    final keys = _prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith(statusPrefix) || key.startsWith(metaPrefix)) {
        await _prefs.remove(key);
      }
    }

    try {
      final dir = await _getDir();
      final files = dir.listSync();
      for (final f in files) {
        if (f is File && f.path.split('/').last.startsWith(filePrefix)) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  /// Clear all cached floor plans
  Future<void> clearAllCache() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheStatusKeyPrefix) ||
          key.startsWith(_cacheMetaKeyPrefix)) {
        await _prefs.remove(key);
      }
    }

    try {
      final dir = await _getDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Get cache timestamp
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

  /// Check if cache is stale
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
