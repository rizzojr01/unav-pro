import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage user's selected location configuration (place, building, floor)
class LocationConfigService {
  final SharedPreferences _prefs;

  static const String _keyPlace = 'location_config_place';
  static const String _keyBuilding = 'location_config_building';
  static const String _keyFloor = 'location_config_floor';

  // Default values
  static const String defaultPlace = 'New_York_City';
  static const String defaultBuilding = 'LightHouse';
  static const String defaultFloor = '6_floor';

  static const String _keyUseSampleImage = 'debug_use_sample_image';

  LocationConfigService(this._prefs);

  /// Get whether to use sample image for localization
  bool get useSampleImage => _prefs.getBool(_keyUseSampleImage) ?? false;

  /// Set whether to use sample image for localization
  Future<void> setUseSampleImage(bool value) async {
    await _prefs.setBool(_keyUseSampleImage, value);
  }

  /// Get the selected place
  String get place => _prefs.getString(_keyPlace) ?? defaultPlace;

  /// Get the selected building
  String get building => _prefs.getString(_keyBuilding) ?? defaultBuilding;

  /// Get the selected floor
  String get floor => _prefs.getString(_keyFloor) ?? defaultFloor;

  /// Save the selected place
  Future<void> setPlace(String value) async {
    await _prefs.setString(_keyPlace, value);
  }

  /// Save the selected building
  Future<void> setBuilding(String value) async {
    await _prefs.setString(_keyBuilding, value);
  }

  /// Save the selected floor
  Future<void> setFloor(String value) async {
    await _prefs.setString(_keyFloor, value);
  }

  /// Save all location config at once
  Future<void> saveConfig({
    required String place,
    required String building,
    required String floor,
  }) async {
    await Future.wait([
      setPlace(place),
      setBuilding(building),
      setFloor(floor),
    ]);
  }

  /// Check if location is configured (not using defaults)
  bool get isConfigured => _prefs.containsKey(_keyPlace);

  /// Clear all location config
  Future<void> clearConfig() async {
    await Future.wait([
      _prefs.remove(_keyPlace),
      _prefs.remove(_keyBuilding),
      _prefs.remove(_keyFloor),
    ]);
  }
}
