import '../../../../injection.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../locate_me/data/datasources/locate_me_remote_datasource.dart';
import '../../../../shared/data/datasources/place_remote_datasource.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'floor_map_event.dart';
import 'floor_map_state.dart';

import 'package:stream_transform/stream_transform.dart';

EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class FloorMapBloc extends Bloc<FloorMapEvent, FloorMapState> {
  final FloorPlanCacheService floorPlanCacheService =
      getIt<FloorPlanCacheService>();
  final LocationConfigService locationConfigService =
      getIt<LocationConfigService>();
  final PlaceRemoteDataSource placeRemoteDataSource =
      getIt<PlaceRemoteDataSource>();
  final LocateMeRemoteDataSource locateMeRemoteDataSource =
      getIt<LocateMeRemoteDataSource>();

  FloorMapBloc() : super(const FloorMapInitial()) {
    on<FloorMapInitialized>(_onInitialized);
    on<FloorMapFloorChanged>(
      _onFloorChanged,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<FloorMapLocationSelected>(_onLocationSelected);
    on<FloorMapMarkerConfirmed>(_onMarkerConfirmed);
  }

  Future<void> _onInitialized(
    FloorMapInitialized event,
    Emitter<FloorMapState> emit,
  ) async {
    emit(const FloorMapLoading());

    try {
      final places = await placeRemoteDataSource.getPlaceDetails();
      final currentPlace = places
          .where((p) => p.name == locationConfigService.place)
          .firstOrNull;

      List<String> floors = [];
      if (currentPlace != null) {
        final currentBuilding = currentPlace.buildings
            .where((b) => b.name == locationConfigService.building)
            .firstOrNull;
        if (currentBuilding != null) {
          floors = currentBuilding.floors.map((f) => f.name).toList();
        }
      }

      final effectiveFloor = event.initialFloor ?? locationConfigService.floor;

      final floorPlan = await floorPlanCacheService.getCachedFloorPlanBase64(
        place: locationConfigService.place,
        building: locationConfigService.building,
        floor: effectiveFloor,
      );

      emit(
        FloorMapReady(
          base64FloorPlan: floorPlan,
          availableFloors: floors,
          selectedFloor: effectiveFloor,
        ),
      );
    } catch (e) {
      emit(FloorMapError(e.toString()));
    }
  }

  Future<void> _onFloorChanged(
    FloorMapFloorChanged event,
    Emitter<FloorMapState> emit,
  ) async {
    final currentState = state;
    if (currentState is! FloorMapReady) return;

    // Check cache first
    final cached = await floorPlanCacheService.getCachedFloorPlanBase64(
      place: locationConfigService.place,
      building: locationConfigService.building,
      floor: event.floor,
    );

    if (cached != null) {
      emit(
        currentState.copyWith(
          selectedFloor: event.floor,
          base64FloorPlan: cached,
        ),
      );
      return;
    }

    // Fetch from API if not cached
    emit(const FloorMapLoading());
    try {
      final floorPlan = await locateMeRemoteDataSource.getFloorPlan(
        place: locationConfigService.place,
        building: locationConfigService.building,
        floor: event.floor,
      );

      // Cache it
      await floorPlanCacheService.cacheFloorPlan(
        place: locationConfigService.place,
        building: locationConfigService.building,
        floor: event.floor,
        base64Image: floorPlan.base64Image,
      );

      emit(
        currentState.copyWith(
          selectedFloor: event.floor,
          base64FloorPlan: floorPlan.base64Image,
        ),
      );
    } catch (e) {
      emit(FloorMapError(e.toString()));
    }
  }

  void _onLocationSelected(
    FloorMapLocationSelected event,
    Emitter<FloorMapState> emit,
  ) {
    emit(FloorMapMarkerPlaced(event.x, event.y));
  }

  void _onMarkerConfirmed(
    FloorMapMarkerConfirmed event,
    Emitter<FloorMapState> emit,
  ) {
    // Handled in UI
  }
}
