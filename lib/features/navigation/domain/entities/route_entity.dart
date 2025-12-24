import '../../../../core/base/base_entity.dart';
import 'location_entity.dart';

class RouteEntity extends BaseEntity {
  final String id;
  final LocationEntity origin;
  final LocationEntity destination;
  final List<LocationEntity> waypoints;
  final double distanceInMeters;
  final int durationInSeconds;

  const RouteEntity({
    required this.id,
    required this.origin,
    required this.destination,
    required this.waypoints,
    required this.distanceInMeters,
    required this.durationInSeconds,
  });

  @override
  List<Object?> get props => [
    id,
    origin,
    destination,
    waypoints,
    distanceInMeters,
    durationInSeconds,
  ];
}
