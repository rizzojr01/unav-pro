import '../../domain/entities/wifi_mapping_entity.dart';

/// Data model for [WifiMappingEntity] — handles JSON serialization
/// for storage in SharedPreferences.
class WifiMappingModel extends WifiMappingEntity {
  const WifiMappingModel({
    required super.bssid,
    required super.ssid,
    required super.placeName,
    required super.buildingName,
    super.floorName,
    required super.createdAt,
  });

  factory WifiMappingModel.fromJson(Map<String, dynamic> json) {
    return WifiMappingModel(
      bssid: json['bssid'] as String,
      ssid: json['ssid'] as String? ?? '',
      placeName: json['place_name'] as String,
      buildingName: json['building_name'] as String,
      floorName: json['floor_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bssid': bssid,
      'ssid': ssid,
      'place_name': placeName,
      'building_name': buildingName,
      if (floorName != null) 'floor_name': floorName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WifiMappingModel.fromEntity(WifiMappingEntity entity) {
    return WifiMappingModel(
      bssid: entity.bssid,
      ssid: entity.ssid,
      placeName: entity.placeName,
      buildingName: entity.buildingName,
      floorName: entity.floorName,
      createdAt: entity.createdAt,
    );
  }
}
