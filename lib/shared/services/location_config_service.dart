import 'package:flutter/foundation.dart';
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
  static const String _keyUnit = 'navigation_unit';
  static const String _keyShowDebugBanner = 'debug_show_banner';
  static const String _keyArHeadingOffsetDeg = 'ar_heading_offset_deg';
  static const String _keySnapToRoute = 'snap_to_route';
  static const String _keyAutoHeadingCorrection = 'auto_heading_correction';
  static const String _keyDirectionBucketMode = 'direction_bucket_mode';
  static const String _keyDirectionBucketCount = 'direction_bucket_count';

  LocationConfigService(this._prefs);

  late final ValueNotifier<bool> debugBannerNotifier =
      ValueNotifier(_prefs.getBool(_keyShowDebugBanner) ?? false);

  late final ValueNotifier<String> unitNotifier =
      ValueNotifier(_prefs.getString(_keyUnit) ?? 'meter');

  /// Live-tunable rotation offset (degrees) applied to ARKit world frame
  /// when mapping to floorplan space and projecting paths back to AR.
  /// Used to compensate for compass drift or floorplan-AR misalignment.
  late final ValueNotifier<double> arHeadingOffsetDegNotifier =
      ValueNotifier(_prefs.getDouble(_keyArHeadingOffsetDeg) ?? 0.0);

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
  late final ValueNotifier<double> offsetInMetersNotifier =
      ValueNotifier(_prefs.getDouble(_keyOffsetInMeters) ?? 0.0);

  double get offsetInMeters => offsetInMetersNotifier.value;

  Future<void> setOffsetInMeters(double value) async {
    offsetInMetersNotifier.value = value;
    await _prefs.setDouble(_keyOffsetInMeters, value);
  }

  /// Unit (feet/meter)
  String get unit => unitNotifier.value;

  Future<void> setUnit(String value) async {
    unitNotifier.value = value;
    await _prefs.setString(_keyUnit, value);
  }

  bool get showDebugBanner => debugBannerNotifier.value;

  Future<void> setShowDebugBanner(bool value) async {
    debugBannerNotifier.value = value;
    await _prefs.setBool(_keyShowDebugBanner, value);
  }

  double get arHeadingOffsetDeg => arHeadingOffsetDegNotifier.value;

  Future<void> setArHeadingOffsetDeg(double value) async {
    arHeadingOffsetDegNotifier.value = value;
    await _prefs.setDouble(_keyArHeadingOffsetDeg, value);
  }

  /// Project the user's pose onto the nearest navigable route edge before
  /// display/tracking. Hides server noise and ARKit drift; user toggleable.
  late final ValueNotifier<bool> snapToRouteNotifier =
      ValueNotifier(_prefs.getBool(_keySnapToRoute) ?? true);

  bool get snapToRoute => snapToRouteNotifier.value;

  Future<void> setSnapToRoute(bool value) async {
    snapToRouteNotifier.value = value;
    await _prefs.setBool(_keySnapToRoute, value);
  }

  /// Auto-correct AR heading offset by observing user's walk direction vs
  /// nearest route_segment direction. Hides 2-5° backend/ARKit yaw error.
  /// When enabled, `arHeadingOffsetDeg` is driven automatically; the manual
  /// slider still works as an override (last writer wins per frame).
  late final ValueNotifier<bool> autoHeadingCorrectionNotifier = ValueNotifier(
    _prefs.getBool(_keyAutoHeadingCorrection) ?? true,
  );

  bool get autoHeadingCorrection => autoHeadingCorrectionNotifier.value;

  Future<void> setAutoHeadingCorrection(bool value) async {
    autoHeadingCorrectionNotifier.value = value;
    await _prefs.setBool(_keyAutoHeadingCorrection, value);
  }

  /// "Push train on tracks" mode. When on, AR pose is replaced by a
  /// bucketed-direction tracker — only walk distance + a coarse compass
  /// direction (4 or 8 bin) drive the user dot, which is then snapped onto
  /// the route. Tolerates ±45° (or ±22.5° at 8 buckets) of yaw error and
  /// hides the AR overlay because pixel-accurate alignment is no longer
  /// the goal.
  late final ValueNotifier<bool> directionBucketModeNotifier = ValueNotifier(
    _prefs.getBool(_keyDirectionBucketMode) ?? false,
  );

  bool get directionBucketMode => directionBucketModeNotifier.value;

  Future<void> setDirectionBucketMode(bool value) async {
    directionBucketModeNotifier.value = value;
    await _prefs.setBool(_keyDirectionBucketMode, value);
  }

  /// Bucket resolution for [directionBucketMode]: 4 (N/E/S/W) or 8
  /// (with NE/SE/SW/NW). Defaults to 4 — switch to 8 if N/E/S/W feels too
  /// coarse for the building's corridor angles.
  late final ValueNotifier<int> directionBucketCountNotifier = ValueNotifier(
    _prefs.getInt(_keyDirectionBucketCount) ?? 4,
  );

  int get directionBucketCount => directionBucketCountNotifier.value;

  Future<void> setDirectionBucketCount(int value) async {
    if (value != 4 && value != 8) return;
    directionBucketCountNotifier.value = value;
    await _prefs.setInt(_keyDirectionBucketCount, value);
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
