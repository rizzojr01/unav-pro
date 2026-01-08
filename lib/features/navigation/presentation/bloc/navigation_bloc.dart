import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/usecases/get_route_usecase.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final GetRouteUseCase getRouteUseCase;

  NavigationBloc({required this.getRouteUseCase})
    : super(const NavigationInitial()) {
    on<InitializeNavigationEvent>(_onInitializeNavigation);
  }

  Future<void> _onInitializeNavigation(
    InitializeNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    emit(const NavigationLoading());

    final routeResult = await getRouteUseCase(
      GetRouteParams(
        origin: null,
        destination: LocationEntity(
          x: event.destination.x,
          y: event.destination.y,
          timestamp: DateTime.now(),
        ),
      ),
    );

    routeResult.fold(
      (failure) => emit(NavigationError(failure.message)),
      (route) =>
          emit(NavigationReady(currentLocation: route.origin, route: route)),
    );
  }
}
