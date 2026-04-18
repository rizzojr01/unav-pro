import '../../domain/entities/navigation_step_entity.dart';
import 'location_model.dart';

class NavigationStepModel extends NavigationStepEntity {
  const NavigationStepModel({
    required super.from,
    required super.to,
    required super.distanceMeters,
    required super.distanceFeet,
  });

  factory NavigationStepModel.fromJson(Map<String, dynamic> json) {
    return NavigationStepModel(
      from: LocationModel.fromJson(json['from'] as Map<String, dynamic>),
      to: LocationModel.fromJson(json['to'] as Map<String, dynamic>),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      distanceFeet: json['distance_feet'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': LocationModel.fromEntity(from).toJson(),
      'to': LocationModel.fromEntity(to).toJson(),
      'distance_meters': distanceMeters,
      'distance_feet': distanceFeet,
    };
  }

  factory NavigationStepModel.fromEntity(NavigationStepEntity entity) {
    return NavigationStepModel(
      from: entity.from,
      to: entity.to,
      distanceMeters: entity.distanceMeters,
      distanceFeet: entity.distanceFeet,
    );
  }
}
