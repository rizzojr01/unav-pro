import 'package:equatable/equatable.dart';

/// Represents a stored GPS location → place/building mapping.
///
/// Users save their current GPS coordinates when they manually select a
/// place/building. Future GPS detections compare the user's position against
/// all saved mappings within their configured radius.
class GpsMappingEntity extends Equatable {
  /// Latitude of the saved location
  final double latitude;

  /// Longitude of the saved location
  final double longitude;

  /// Proximity radius in meters — the user is considered "at" this
  /// building if they are within this distance of the saved coordinates.
  final double radiusMeters;

  /// The place name this GPS location maps to
  final String placeName;

  /// The building name this GPS location maps to
  final String buildingName;

  /// When this mapping was created
  final DateTime createdAt;

  const GpsMappingEntity({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150.0,
    required this.placeName,
    required this.buildingName,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        radiusMeters,
        placeName,
        buildingName,
        createdAt,
      ];
}
