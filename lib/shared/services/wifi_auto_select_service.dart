import 'dart:convert';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/wifi_mapping_model.dart';
import '../domain/entities/wifi_mapping_entity.dart';

/// Service that maps Wi-Fi BSSID (hardware MAC address of the access point)
/// to place/building selections.
///
/// The BSSID is used instead of the SSID because:
/// - BSSID is the hardware MAC address — it never changes
/// - SSID (network name) can be shared across many access points
///   or renamed at any time
///
/// Mappings are stored locally in SharedPreferences as a JSON list.
class WifiAutoSelectService {
  final SharedPreferences _prefs;
  final NetworkInfo _networkInfo;

  static const String _mappingsKey = 'wifi_bssid_mappings';

  WifiAutoSelectService({
    required SharedPreferences prefs,
    NetworkInfo? networkInfo,
  })  : _prefs = prefs,
        _networkInfo = networkInfo ?? NetworkInfo();

  // ---------------------------------------------------------------------------
  // Current WiFi info
  // ---------------------------------------------------------------------------

  /// Returns the BSSID of the currently connected WiFi access point.
  /// Returns `null` if:
  /// - The device is not connected to WiFi
  /// - The required permissions are not granted
  /// - Running on a platform that doesn't support WiFi info
  Future<String?> getCurrentBssid() async {
    try {
      final bssid = await _networkInfo.getWifiBSSID();
      // Some platforms return empty string or "02:00:00:00:00:00" (masked)
      if (bssid == null || bssid.isEmpty || bssid == '02:00:00:00:00:00') {
        return null;
      }
      return bssid.toLowerCase(); // normalise to lower-case for consistent matching
    } catch (_) {
      return null;
    }
  }

  /// Returns the SSID of the currently connected WiFi network (for display).
  Future<String?> getCurrentSsid() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      // Android wraps SSIDs in quotes — strip them
      if (ssid == null) return null;
      return ssid.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping CRUD
  // ---------------------------------------------------------------------------

  /// Returns all stored BSSID→place/building mappings.
  List<WifiMappingEntity> getAllMappings() {
    final raw = _prefs.getString(_mappingsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => WifiMappingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Looks up a stored mapping for the given [bssid].
  /// Returns `null` if no mapping exists.
  WifiMappingEntity? getMappingForBssid(String bssid) {
    final normalised = bssid.toLowerCase();
    try {
      return getAllMappings().firstWhere((m) => m.bssid == normalised);
    } catch (_) {
      return null;
    }
  }

  /// Saves (or overwrites) a BSSID → place/building mapping.
  Future<void> saveMapping(WifiMappingEntity mapping) async {
    final mappings = getAllMappings();
    // Remove any existing entry for this BSSID
    final updated = mappings.where((m) => m.bssid != mapping.bssid).toList();
    updated.add(WifiMappingModel.fromEntity(mapping));
    await _persist(updated);
  }

  /// Removes the mapping for a given [bssid].
  Future<void> removeMapping(String bssid) async {
    final normalised = bssid.toLowerCase();
    final mappings = getAllMappings()
        .where((m) => m.bssid != normalised)
        .toList();
    await _persist(mappings);
  }

  /// Clears all stored mappings.
  Future<void> clearAllMappings() async {
    await _prefs.remove(_mappingsKey);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _persist(List<WifiMappingEntity> mappings) async {
    final json = jsonEncode(
      mappings
          .map((m) => WifiMappingModel.fromEntity(m).toJson())
          .toList(),
    );
    await _prefs.setString(_mappingsKey, json);
  }
}
