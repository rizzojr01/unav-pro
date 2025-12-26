import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/base/usecase.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/usecases/get_current_location_usecase.dart';
import '../../domain/usecases/get_route_usecase.dart';
import '../../domain/usecases/watch_location_usecase.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final GetCurrentLocationUseCase getCurrentLocationUseCase;
  final GetRouteUseCase getRouteUseCase;
  final WatchLocationUseCase watchLocationUseCase;

  StreamSubscription<LocationEntity>? _locationSubscription;

  NavigationBloc({
    required this.getCurrentLocationUseCase,
    required this.getRouteUseCase,
    required this.watchLocationUseCase,
  }) : super(const NavigationInitial()) {
    on<InitializeNavigationEvent>(_onInitializeNavigation);
    on<StartNavigationEvent>(_onStartNavigation);
    on<StopNavigationEvent>(_onStopNavigation);
    on<UpdateLocationEvent>(_onUpdateLocation);
  }

  Future<void> _onInitializeNavigation(
    InitializeNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    emit(const NavigationLoading());

    // Get current location
    final locationResult = await getCurrentLocationUseCase(const NoParams());

    await locationResult.fold(
      (failure) async => emit(NavigationError(failure.message)),
      (currentLocation) async {
        // Get route to destination
        final routeResult = await getRouteUseCase(
          GetRouteParams(
            origin: currentLocation,
            destination: LocationEntity(
              latitude: event.destination.latitude,
              longitude: event.destination.longitude,
              timestamp: DateTime.now(),
            ),
          ),
        );

        routeResult.fold(
          (failure) => emit(NavigationError(failure.message)),
          (route) => emit(
            NavigationReady(currentLocation: currentLocation, route: route),
          ),
        );
      },
    );
  }

  Future<void> _onStartNavigation(
    StartNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    if (state is! NavigationReady) return;

    final currentState = state as NavigationReady;
    emit(
      NavigationInProgress(
        currentLocation: currentState.currentLocation,
        route: currentState.route,
      ),
    );

    // Start watching location updates
    _locationSubscription = watchLocationUseCase().listen((location) {
      add(const UpdateLocationEvent());
    });
  }

  Future<void> _onStopNavigation(
    StopNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    if (state is NavigationInProgress) {
      final currentState = state as NavigationInProgress;
      emit(
        NavigationReady(
          currentLocation: currentState.currentLocation,
          route: currentState.route,
        ),
      );
    }
  }

  Future<void> _onUpdateLocation(
    UpdateLocationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    if (state is! NavigationInProgress) return;

    final currentState = state as NavigationInProgress;

    // Get updated location
    final locationResult = await getCurrentLocationUseCase(const NoParams());

    locationResult.fold(
      (failure) => null, // Ignore errors during updates
      (location) {
        emit(
          NavigationInProgress(
            currentLocation: location,
            route: currentState.route,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
