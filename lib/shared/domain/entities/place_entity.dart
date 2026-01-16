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

  const BuildingEntity({
    required this.id,
    required this.name,
    required this.floors,
  });

  @override
  List<Object?> get props => [id, name, floors];
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
