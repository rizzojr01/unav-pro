import '../../../../core/base/base_state.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';

abstract class NavigationState extends BaseState {
  const NavigationState();
}

class NavigationInitial extends NavigationState {
  const NavigationInitial();
}

class NavigationLoading extends NavigationState {
  const NavigationLoading();
}

class NavigationReady extends NavigationState {
  final LocationEntity currentLocation;
  final RouteEntity route;

  const NavigationReady({required this.currentLocation, required this.route});

  @override
  List<Object?> get props => [currentLocation, route];
}

class NavigationInProgress extends NavigationState {
  final LocationEntity currentLocation;
  final RouteEntity route;

  const NavigationInProgress({
    required this.currentLocation,
    required this.route,
  });

  @override
  List<Object?> get props => [currentLocation, route];
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
