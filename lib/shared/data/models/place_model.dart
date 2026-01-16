import '../../domain/entities/place_entity.dart';

class FloorModel extends FloorEntity {
  const FloorModel({
    required super.id,
    required super.level,
    required super.name,
  });

  factory FloorModel.fromJson(Map<String, dynamic> json) {
    return FloorModel(
      id: json['id'] as String,
      level: json['level'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'level': level, 'name': name};
  }
}

class BuildingModel extends BuildingEntity {
  const BuildingModel({
    required super.id,
    required super.name,
    required super.floors,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    final floorsJson = json['floors'] as List<dynamic>? ?? [];
    return BuildingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      floors: floorsJson.map((f) => FloorModel.fromJson(f)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'floors': floors
          .map(
            (f) => FloorModel(id: f.id, level: f.level, name: f.name).toJson(),
          )
          .toList(),
    };
  }
}

class PlaceModel extends PlaceEntity {
  const PlaceModel({
    required super.id,
    required super.name,
    required super.buildings,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final buildingsJson = json['buildings'] as List<dynamic>? ?? [];
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      buildings: buildingsJson.map((b) => BuildingModel.fromJson(b)).toList(),
    );
  }

  static List<PlaceModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => PlaceModel.fromJson(json)).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'buildings': buildings
          .map(
            (b) => BuildingModel(
              id: b.id,
              name: b.name,
              floors: b.floors,
            ).toJson(),
          )
          .toList(),
    };
  }
}
