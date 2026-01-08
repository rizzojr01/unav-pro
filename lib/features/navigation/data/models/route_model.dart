import '../../domain/entities/route_entity.dart';
import 'location_model.dart';
import 'navigation_step_model.dart';

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.entityId,
    required super.origin,
    required super.destination,
    required super.waypoints,
    required super.steps,
    required super.distanceInMeters,
    required super.durationInSeconds,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      entityId: json['id'] as String? ?? '',
      origin: json['origin'] != null
          ? LocationModel.fromJson(json['origin'] as Map<String, dynamic>)
          : (json['navigation_steps'] != null &&
                (json['navigation_steps'] as List).isNotEmpty)
          ? NavigationStepModel.fromJson(
              json['navigation_steps'][0] as Map<String, dynamic>,
            ).from
          : const LocationModel(x: 0, y: 0),
      destination: json['destination'] != null
          ? LocationModel.fromJson(json['destination'] as Map<String, dynamic>)
          : (json['navigation_steps'] != null &&
                (json['navigation_steps'] as List).isNotEmpty)
          ? NavigationStepModel.fromJson(
              (json['navigation_steps'] as List).last as Map<String, dynamic>,
            ).to
          : const LocationModel(x: 0, y: 0),
      waypoints:
          (json['waypoints'] as List<dynamic>?)
              ?.map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      steps:
          (json['navigation_steps'] as List<dynamic>?)
              ?.map(
                (e) => NavigationStepModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      distanceInMeters: (json['distanceInMeters'] as num?)?.toDouble() ?? 0.0,
      durationInSeconds: json['durationInSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id!,
      'origin': LocationModel.fromEntity(origin).toJson(),
      'destination': LocationModel.fromEntity(destination).toJson(),
      'waypoints': waypoints
          .map((e) => LocationModel.fromEntity(e).toJson())
          .toList(),
      'navigation_steps': steps
          .map((e) => NavigationStepModel.fromEntity(e).toJson())
          .toList(),
      'distanceInMeters': distanceInMeters,
      'durationInSeconds': durationInSeconds,
    };
  }

  factory RouteModel.fromEntity(RouteEntity entity) {
    return RouteModel(
      entityId: entity.id!,
      origin: entity.origin,
      destination: entity.destination,
      waypoints: entity.waypoints,
      steps: entity.steps,
      distanceInMeters: entity.distanceInMeters,
      durationInSeconds: entity.durationInSeconds,
    );
  }
}
