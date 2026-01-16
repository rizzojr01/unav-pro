import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage debug configuration settings
class DebugConfigService {
  final SharedPreferences _prefs;

  static const String _keyUseSampleImage = 'debug_use_sample_image';

  DebugConfigService(this._prefs);

  /// Get whether to use sample image for localization
  bool get useSampleImage => _prefs.getBool(_keyUseSampleImage) ?? false;

  /// Set whether to use sample image for localization
  Future<void> setUseSampleImage(bool value) async {
    await _prefs.setBool(_keyUseSampleImage, value);
  }

  /// Toggle use sample image setting
  Future<bool> toggleUseSampleImage() async {
    final newValue = !useSampleImage;
    await setUseSampleImage(newValue);
    return newValue;
  }
}
