import '../../../../core/base/base_state.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';

abstract class NavigationState extends BaseState {
  const NavigationState();
}

class NavigationInitial extends NavigationState {
  const NavigationInitial();
}

class NavigationLoading extends NavigationState {
  final String? message;

  const NavigationLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class NavigationReady extends NavigationState {
  final LocationEntity currentLocation;
  final RouteEntity route;
  final String? floorPlanBase64;
  final List<DestinationEntity> destinations;
  final double? metersPerPixel;

  /// floor key → base64 floor plan (populated for multi-floor routes)
  final Map<String, String> floorPlansByFloor;

  /// floor key → destinations list (populated for multi-floor routes)
  final Map<String, List<DestinationEntity>> destinationsByFloor;

  const NavigationReady({
    required this.currentLocation,
    required this.route,
    this.floorPlanBase64,
    this.destinations = const [],
    this.floorPlansByFloor = const {},
    this.destinationsByFloor = const {},
    this.metersPerPixel,
  });

  @override
  List<Object?> get props => [
    currentLocation,
    route,
    floorPlanBase64,
    destinations,
    floorPlansByFloor,
    destinationsByFloor,
    metersPerPixel,
  ];
}

class NavigationCompleted extends NavigationState {
  const NavigationCompleted();
}

class NavigationError extends NavigationState {
  final String message;

  const NavigationError(this.message);

  @override
  List<Object?> get props => [message];
}
