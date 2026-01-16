import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/debug_config_service.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../locate_me/domain/usecases/get_floor_plan_usecase.dart';
import '../../domain/usecases/get_route_usecase.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final GetRouteUseCase getRouteUseCase;
  final GetFloorPlanUseCase getFloorPlanUseCase;
  final LocationConfigService locationConfigService;
  final FloorPlanCacheService floorPlanCacheService;
  final DebugConfigService debugConfigService;

  NavigationBloc({
    required this.getRouteUseCase,
    required this.getFloorPlanUseCase,
    required this.locationConfigService,
    required this.floorPlanCacheService,
    required this.debugConfigService,
  }) : super(const NavigationInitial()) {
    on<InitializeNavigationEvent>(_onInitializeNavigation);
  }

  Future<void> _onInitializeNavigation(
    InitializeNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    final place = locationConfigService.place;
    final building = locationConfigService.building;
    final floor = locationConfigService.floor;
    final destinationId = event.destination.destinationId;
    final sessionId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    final useSampleImage = debugConfigService.useSampleImage;

    emit(const NavigationLoading(message: 'Loading floor plan...'));

    String? floorPlanBase64;
    String? floorPlanError;

    // Step 1: Check cache first
    if (floorPlanCacheService.hasCachedFloorPlan(
      place: place,
      building: building,
      floor: floor,
    )) {
      // Use cached floor plan
      floorPlanBase64 = floorPlanCacheService.getCachedFloorPlanBase64(
        place: place,
        building: building,
        floor: floor,
      );
    } else {
      // Fetch from API
      final floorPlanResult = await getFloorPlanUseCase(
        GetFloorPlanParams(building: building, floor: floor, place: place),
      );

      await floorPlanResult.fold(
        (failure) async {
          floorPlanError = failure.message;
        },
        (floorPlan) async {
          floorPlanBase64 = floorPlan.base64Image;
          // Cache the floor plan for future use
          if (floorPlanBase64 != null && floorPlanBase64!.isNotEmpty) {
            await floorPlanCacheService.cacheFloorPlan(
              place: place,
              building: building,
              floor: floor,
              base64Image: floorPlanBase64!,
            );
          }
        },
      );
    }

    // If floor plan failed and no cache, show error
    if (floorPlanBase64 == null || floorPlanBase64!.isEmpty) {
      emit(
        NavigationError(
          floorPlanError ?? 'Failed to load floor plan. Please try again.',
        ),
      );
      return;
    }

    // Step 2: Get route
    emit(const NavigationLoading(message: 'Calculating route...'));

    final routeResult = await getRouteUseCase(
      GetRouteParams(
        destinationId: destinationId,
        place: place,
        building: building,
        floor: floor,
        sessionId: sessionId,
        useSampleImage: useSampleImage,
      ),
    );

    routeResult.fold(
      (failure) => emit(NavigationError(failure.message)),
      (route) => emit(
        NavigationReady(
          currentLocation: route.origin,
          route: route,
          floorPlanBase64: floorPlanBase64,
        ),
      ),
    );
  }
}
