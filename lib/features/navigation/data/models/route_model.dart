import '../../domain/entities/route_entity.dart';
import '../../domain/entities/navigation_step_entity.dart';
import 'location_model.dart';
import 'navigation_step_model.dart';
import 'multi_floor_navigation_step_model.dart';

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.entityId,
    required super.origin,
    required super.destination,
    required super.waypoints,
    required super.steps,
    super.multiFloorSteps,
    required super.distanceInMeters,
    required super.durationInSeconds,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    // Parse individual step lists first
    final flatSteps =
        (json['navigation_steps'] as List<dynamic>?)
            ?.map(
              (e) => NavigationStepModel.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];

    final multiSteps =
        (json['multifloor_navigation_steps'] as List<dynamic>?)
            ?.map(
              (e) => MultiFloorNavigationStepModel.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList() ??
        [];

    // If flat steps are empty but we have multi-floor steps, flatten them
    // so existing UI generic logic works (assuming single floor visualization for now
    // or sequential plotting)
    final List<NavigationStepEntity> effectiveSteps = flatSteps.isNotEmpty
        ? flatSteps
        : multiSteps.expand((floor) => floor.steps).toList();

    // Helper to find initial origin
    LocationModel getOrigin() {
      if (json['origin'] != null) {
        return LocationModel.fromJson(json['origin'] as Map<String, dynamic>);
      }
      if (effectiveSteps.isNotEmpty) {
        return LocationModel.fromEntity(effectiveSteps.first.from);
      }
      return const LocationModel(x: 0, y: 0);
    }

    // Helper to find final destination
    LocationModel getDestination() {
      if (json['destination'] != null) {
        return LocationModel.fromJson(
          json['destination'] as Map<String, dynamic>,
        );
      }
      if (effectiveSteps.isNotEmpty) {
        return LocationModel.fromEntity(effectiveSteps.last.to);
      }
      return const LocationModel(x: 0, y: 0);
    }

    return RouteModel(
      entityId: json['id'] as String? ?? '',
      origin: getOrigin(),
      destination: getDestination(),
      waypoints:
          (json['waypoints'] as List<dynamic>?)
              ?.map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      steps: effectiveSteps,
      multiFloorSteps: multiSteps,
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
      'multifloor_navigation_steps': multiFloorSteps
          ?.map((e) => MultiFloorNavigationStepModel.fromEntity(e).toJson())
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
      multiFloorSteps: entity.multiFloorSteps,
      distanceInMeters: entity.distanceInMeters,
      durationInSeconds: entity.durationInSeconds,
    );
  }
}
