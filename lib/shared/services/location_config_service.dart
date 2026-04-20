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
  static const String _keyEnableCompression = 'image_compression_enabled';
  static const String _keyMaxHeight = 'image_compression_max_height';
  static const String _keyMaxWidth = 'image_compression_max_width';
  static const String _keyImageQuality = 'image_compression_quality';
  static const String _keySaveFrame = 'navigation_save_frame';
  static const String _keyMultiFloor = 'navigation_multifloor';
  static const String _keyUseAlternateSampleImage =
      'use_alternate_sample_image';
  static const String _keyAlternateSampleImagePath =
      'alternate_sample_image_path';
  static const String _keyOffsetInMeters = 'navigation_offset_in_meters';

  LocationConfigService(this._prefs);

  /// Get whether to use sample image for localization
  bool get useSampleImage => _prefs.getBool(_keyUseSampleImage) ?? false;

  /// Set whether to use sample image for localization
  Future<void> setUseSampleImage(bool value) async {
    await _prefs.setBool(_keyUseSampleImage, value);
  }

  /// Alternate Sample Image Settings
  bool get useAlternateSampleImage =>
      _prefs.getBool(_keyUseAlternateSampleImage) ?? false;
  String get alternateSampleImagePath =>
      _prefs.getString(_keyAlternateSampleImagePath) ??
      'assets/node_images/Node1_N.jpg';

  Future<void> setUseAlternateSampleImage(bool value) async {
    await _prefs.setBool(_keyUseAlternateSampleImage, value);
  }

  Future<void> setAlternateSampleImagePath(String value) async {
    await _prefs.setString(_keyAlternateSampleImagePath, value);
  }

  /// Image Compression Settings
  bool get enableCompression => _prefs.getBool(_keyEnableCompression) ?? false;
  int get maxHeight => _prefs.getInt(_keyMaxHeight) ?? 640;
  int get maxWidth => _prefs.getInt(_keyMaxWidth) ?? 360;
  int get imageQuality => _prefs.getInt(_keyImageQuality) ?? 100;
  bool get saveFrame => _prefs.getBool(_keySaveFrame) ?? false;

  Future<void> setEnableCompression(bool value) async {
    await _prefs.setBool(_keyEnableCompression, value);
  }

  Future<void> setMaxHeight(int value) async {
    await _prefs.setInt(_keyMaxHeight, value);
  }

  Future<void> setMaxWidth(int value) async {
    await _prefs.setInt(_keyMaxWidth, value);
  }

  Future<void> setImageQuality(int value) async {
    await _prefs.setInt(_keyImageQuality, value);
  }

  Future<void> setSaveFrame(bool value) async {
    await _prefs.setBool(_keySaveFrame, value);
  }

  /// Multi-floor navigation — sends `unav_multifloor` in route request
  bool get multiFloorNavigation =>
      _prefs.getBool(_keyMultiFloor) ?? true; // on by default

  Future<void> setMultiFloorNavigation(bool value) async {
    await _prefs.setBool(_keyMultiFloor, value);
  }

  /// Offset in meters for navigation and localization
  double get offsetInMeters => _prefs.getDouble(_keyOffsetInMeters) ?? 0.0;

  Future<void> setOffsetInMeters(double value) async {
    await _prefs.setDouble(_keyOffsetInMeters, value);
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
