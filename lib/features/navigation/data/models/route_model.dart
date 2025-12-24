import '../../domain/entities/route_entity.dart';
import 'location_model.dart';

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    required super.origin,
    required super.destination,
    required super.waypoints,
    required super.distanceInMeters,
    required super.durationInSeconds,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      origin: LocationModel.fromJson(json['origin'] as Map<String, dynamic>),
      destination: LocationModel.fromJson(
        json['destination'] as Map<String, dynamic>,
      ),
      waypoints: (json['waypoints'] as List<dynamic>)
          .map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceInMeters: (json['distanceInMeters'] as num).toDouble(),
      durationInSeconds: json['durationInSeconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': LocationModel.fromEntity(origin).toJson(),
      'destination': LocationModel.fromEntity(destination).toJson(),
      'waypoints': waypoints
          .map((e) => LocationModel.fromEntity(e).toJson())
          .toList(),
      'distanceInMeters': distanceInMeters,
      'durationInSeconds': durationInSeconds,
    };
  }

  factory RouteModel.fromEntity(RouteEntity entity) {
    return RouteModel(
      id: entity.id,
      origin: entity.origin,
      destination: entity.destination,
      waypoints: entity.waypoints,
      distanceInMeters: entity.distanceInMeters,
      durationInSeconds: entity.durationInSeconds,
    );
  }
}
