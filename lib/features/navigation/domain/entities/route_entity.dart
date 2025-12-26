import '../../../../core/base/base_entity.dart';
import 'location_entity.dart';

class RouteEntity extends BaseEntity {
  final String entityId;
  final LocationEntity origin;
  final LocationEntity destination;
  final List<LocationEntity> waypoints;
  final double distanceInMeters;
  final int durationInSeconds;

  const RouteEntity({
    required this.entityId,
    required this.origin,
    required this.destination,
    required this.waypoints,
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
    distanceInMeters,
    durationInSeconds,
  ];
}
