import '../../../../core/base/base_entity.dart';
import 'location_entity.dart';
import 'navigation_step_entity.dart';
import 'multi_floor_navigation_step_entity.dart';

class RouteEntity extends BaseEntity {
  final String entityId;
  final LocationEntity origin;
  final LocationEntity destination;
  final List<LocationEntity> waypoints;
  final List<NavigationStepEntity> steps;
  final List<MultiFloorNavigationStepEntity>? multiFloorSteps;
  final double distanceInMeters;
  final int durationInSeconds;

  const RouteEntity({
    required this.entityId,
    required this.origin,
    required this.destination,
    required this.waypoints,
    required this.steps,
    this.multiFloorSteps,
    required this.distanceInMeters,
    required this.durationInSeconds,
  });

  @override
  String? get id => entityId;

  @override
  List<Object?> get props => [
    entityId,
    origin,
    destination,
    waypoints,
    steps,
    multiFloorSteps,
    distanceInMeters,
    durationInSeconds,
  ];
}
