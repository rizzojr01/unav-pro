import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to manage device identifier
/// Generates a unique device ID on first run and persists it
class DeviceIdService {
  final SharedPreferences _prefs;

  static const String _keyDeviceId = 'device_id';

  DeviceIdService(this._prefs);

  /// Get or create device ID
  /// Returns the same ID on subsequent calls
  String getDeviceId() {
    String? deviceId = _prefs.getString(_keyDeviceId);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate new device ID
      deviceId = const Uuid().v4();
      _prefs.setString(_keyDeviceId, deviceId);
    }

    return deviceId;
  }

  /// Clear device ID (for testing purposes)
  Future<void> clearDeviceId() async {
    await _prefs.remove(_keyDeviceId);
  }
}
