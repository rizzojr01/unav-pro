import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to manage device identifier
/// Uses hardware identifiers where possible for persistence across restarts/reinstalls
class DeviceIdService {
  final SharedPreferences _prefs;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _cachedDeviceId;

  static const String _keyDeviceId = 'device_id';

  DeviceIdService(this._prefs);

  /// Initialize the device ID once at startup
  Future<void> init() async {
    if (_cachedDeviceId != null) return;

    // 1. Try to get hardware-based ID first for better persistence
    String? hardwareId;
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        hardwareId = androidInfo.id; // stable android id
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        hardwareId = iosInfo.identifierForVendor; // stable vendor id
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        hardwareId = macInfo.systemGUID;
      }
    } catch (e) {
      // Fallback to shared preferences if hardware ID fails
    }

    if (hardwareId != null && hardwareId.isNotEmpty) {
      _cachedDeviceId = hardwareId;
      // Also save to prefs as backup
      await _prefs.setString(_keyDeviceId, hardwareId);
      return;
    }

    // 2. Fallback to existing persisted ID in SharedPreferences
    String? persistedId = _prefs.getString(_keyDeviceId);
    if (persistedId != null && persistedId.isNotEmpty) {
      _cachedDeviceId = persistedId;
      return;
    }

    // 3. Last resort: Generate new UUID and persist it
    final newId = const Uuid().v4();
    await _prefs.setString(_keyDeviceId, newId);
    _cachedDeviceId = newId;
  }

  /// Get device ID (returns the one prepared in init)
  String getDeviceId() {
    if (_cachedDeviceId == null) {
      // This shouldn't normally happen if init() was called and awaited
      // but we return whatever is in prefs as an emergency fallback
      return _prefs.getString(_keyDeviceId) ?? 'unknown_device';
    }
    return _cachedDeviceId!;
  }

  /// Clear device ID (mostly for testing)
  Future<void> clearDeviceId() async {
    _cachedDeviceId = null;
    await _prefs.remove(_keyDeviceId);
  }
}
