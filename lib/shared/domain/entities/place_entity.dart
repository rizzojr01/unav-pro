import 'package:equatable/equatable.dart';

/// Entity representing a floor in a building
class FloorEntity extends Equatable {
  final String id;
  final int level;
  final String name;

  const FloorEntity({
    required this.id,
    required this.level,
    required this.name,
  });

  @override
  List<Object?> get props => [id, level, name];
}

/// Entity representing a building with floors
class BuildingEntity extends Equatable {
  final String id;
  final String name;
  final List<FloorEntity> floors;

  /// GPS coordinates of the building's entrance/center (nullable — set when available from API)
  final double? latitude;
  final double? longitude;

  /// Approximate radius in meters within which a user is considered "inside" this building
  final double? radiusMeters;

  const BuildingEntity({
    required this.id,
    required this.name,
    required this.floors,
    this.latitude,
    this.longitude,
    this.radiusMeters,
  });

  /// Returns true if this building has GPS coordinates configured
  bool get hasGpsCoordinates =>
      latitude != null && longitude != null && radiusMeters != null;

  @override
  List<Object?> get props => [id, name, floors, latitude, longitude, radiusMeters];
}

/// Entity representing a place with buildings
class PlaceEntity extends Equatable {
  final String id;
  final String name;
  final List<BuildingEntity> buildings;

  const PlaceEntity({
    required this.id,
    required this.name,
    required this.buildings,
  });

  @override
  List<Object?> get props => [id, name, buildings];
}
