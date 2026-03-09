import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/gps_mapping_model.dart';
import '../domain/entities/gps_mapping_entity.dart';
import '../domain/entities/place_entity.dart';
import 'location_service.dart';

/// Service that uses GPS coordinates to automatically detect which
/// place + building the user is currently near.
///
/// Detection works from two sources:
/// 1. **Local mappings** — user-saved GPS coordinates stored on-device
/// 2. **Backend coordinates** — GPS fields on BuildingEntity (if available)
///
/// Detection is place + building only (not floor) as GPS cannot reliably
/// distinguish between floors in a multi-storey building.
class GpsAutoSelectService {
  final LocationService locationService;
  final SharedPreferences _prefs;

  static const String _mappingsKey = 'gps_location_mappings';

  GpsAutoSelectService({
    required this.locationService,
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  /// Attempts to find the nearest building that the user is within.
  ///
  /// Checks saved local mappings first, then falls back to BuildingEntity
  /// GPS coordinates (if the backend ever provides them).
  ///
  /// Returns a record with the matched place and building names,
  /// or `null` if no match is found within any radius.
  Future<({String place, String building})?> detectNearestBuilding(
    List<PlaceEntity> places,
  ) async {
    final Position currentPosition = await locationService.getCurrentLocation();

    double? bestDistance;
    String? bestPlace;
    String? bestBuilding;

    // 1. Check saved local GPS mappings
    for (final mapping in getAllMappings()) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        mapping.latitude,
        mapping.longitude,
      );

      if (distance <= mapping.radiusMeters) {
        if (bestDistance == null || distance < bestDistance) {
          bestDistance = distance;
          bestPlace = mapping.placeName;
          bestBuilding = mapping.buildingName;
        }
      }
    }

    // 2. Fallback: check BuildingEntity GPS coordinates (from backend)
    for (final place in places) {
      for (final building in place.buildings) {
        if (!building.hasGpsCoordinates) continue;

        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          building.latitude!,
          building.longitude!,
        );

        final radius = building.radiusMeters!;

        if (distance <= radius) {
          if (bestDistance == null || distance < bestDistance) {
            bestDistance = distance;
            bestPlace = place.name;
            bestBuilding = building.name;
          }
        }
      }
    }

    if (bestPlace != null && bestBuilding != null) {
      return (place: bestPlace, building: bestBuilding);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Mapping CRUD
  // ---------------------------------------------------------------------------

  /// Returns all stored GPS → place/building mappings.
  List<GpsMappingEntity> getAllMappings() {
    final raw = _prefs.getString(_mappingsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => GpsMappingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves a GPS coordinate → place/building mapping.
  /// Overwrites any existing mapping for the same place + building.
  Future<void> saveMapping(GpsMappingEntity mapping) async {
    final mappings = getAllMappings();
    // Remove existing mapping for this place + building
    final updated = mappings
        .where((m) =>
            !(m.placeName == mapping.placeName &&
              m.buildingName == mapping.buildingName))
        .toList();
    updated.add(GpsMappingModel.fromEntity(mapping));
    await _persist(updated);
  }

  /// Removes all mappings for a given place + building.
  Future<void> removeMappingsForBuilding(
    String placeName,
    String buildingName,
  ) async {
    final mappings = getAllMappings()
        .where((m) =>
            !(m.placeName == placeName && m.buildingName == buildingName))
        .toList();
    await _persist(mappings);
  }

  /// Clears all stored GPS mappings.
  Future<void> clearAllMappings() async {
    await _prefs.remove(_mappingsKey);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _persist(List<GpsMappingEntity> mappings) async {
    final json = jsonEncode(
      mappings
          .map((m) => GpsMappingModel.fromEntity(m).toJson())
          .toList(),
    );
    await _prefs.setString(_mappingsKey, json);
  }
}
