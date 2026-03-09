import '../../domain/entities/gps_mapping_entity.dart';

/// Data model for [GpsMappingEntity] — handles JSON serialization
/// for storage in SharedPreferences.
class GpsMappingModel extends GpsMappingEntity {
  const GpsMappingModel({
    required super.latitude,
    required super.longitude,
    super.radiusMeters,
    required super.placeName,
    required super.buildingName,
    required super.createdAt,
  });

  factory GpsMappingModel.fromJson(Map<String, dynamic> json) {
    return GpsMappingModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 150.0,
      placeName: json['place_name'] as String,
      buildingName: json['building_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'place_name': placeName,
      'building_name': buildingName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GpsMappingModel.fromEntity(GpsMappingEntity entity) {
    return GpsMappingModel(
      latitude: entity.latitude,
      longitude: entity.longitude,
      radiusMeters: entity.radiusMeters,
      placeName: entity.placeName,
      buildingName: entity.buildingName,
      createdAt: entity.createdAt,
    );
  }
}
