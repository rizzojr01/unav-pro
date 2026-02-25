import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/place_remote_datasource.dart';
import '../../services/destinations_cache_service.dart';
import '../../services/floor_plan_cache_service.dart';
import '../../services/location_config_service.dart';
import 'location_settings_event.dart';
import 'location_settings_state.dart';

class LocationSettingsBloc
    extends Bloc<LocationSettingsEvent, LocationSettingsState> {
  final PlaceRemoteDataSource placeRemoteDataSource;
  final LocationConfigService locationConfigService;
  final FloorPlanCacheService floorPlanCacheService;
  final DestinationsCacheService destinationsCacheService;

  LocationSettingsBloc({
    required this.placeRemoteDataSource,
    required this.locationConfigService,
    required this.floorPlanCacheService,
    required this.destinationsCacheService,
  }) : super(const LocationSettingsInitial()) {
    on<LoadLocationSettingsEvent>(_onLoad);
    on<SelectPlaceEvent>(_onSelectPlace);
    on<SelectBuildingEvent>(_onSelectBuilding);
    on<SelectFloorEvent>(_onSelectFloor);
    on<SaveLocationSettingsEvent>(_onSave);
  }

  Future<void> _onLoad(
    LoadLocationSettingsEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    emit(const LocationSettingsLoading());

    try {
      final places = await placeRemoteDataSource.getPlaceDetails();

      // Get current saved selection or defaults
      final selectedPlace = locationConfigService.place;
      final selectedBuilding = locationConfigService.building;
      final selectedFloor = locationConfigService.floor;

      emit(
        LocationSettingsLoaded(
          places: places,
          selectedPlace: selectedPlace,
          selectedBuilding: selectedBuilding,
          selectedFloor: selectedFloor,
        ),
      );
    } catch (e) {
      emit(LocationSettingsError(e.toString()));
    }
  }

  Future<void> _onSelectPlace(
    SelectPlaceEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationSettingsLoaded) {
      // When place changes, reset building and floor to first available
      final places = currentState.places;
      final newPlace =
          places.where((p) => p.name == event.placeName).firstOrNull ??
          (places.isNotEmpty ? places.first : null);

      if (newPlace == null) return;

      final newBuilding = newPlace.buildings.isNotEmpty
          ? newPlace.buildings.first
          : null;
      final newFloor = newBuilding != null && newBuilding.floors.isNotEmpty
          ? newBuilding.floors.first
          : null;

      emit(
        currentState.copyWith(
          selectedPlace: event.placeName,
          selectedBuilding: newBuilding?.name ?? '',
          selectedFloor: newFloor?.name ?? '',
        ),
      );
    }
  }

  Future<void> _onSelectBuilding(
    SelectBuildingEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationSettingsLoaded) {
      // When building changes, reset floor to first available
      final currentPlace = currentState.currentPlace;
      if (currentPlace == null) return;

      final buildings = currentPlace.buildings;
      final newBuilding =
          buildings.where((b) => b.name == event.buildingName).firstOrNull ??
          (buildings.isNotEmpty ? buildings.first : null);

      if (newBuilding == null) return;

      final newFloor = newBuilding.floors.isNotEmpty
          ? newBuilding.floors.first
          : null;

      emit(
        currentState.copyWith(
          selectedBuilding: event.buildingName,
          selectedFloor: newFloor?.name ?? '',
        ),
      );
    }
  }

  Future<void> _onSelectFloor(
    SelectFloorEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationSettingsLoaded) {
      emit(currentState.copyWith(selectedFloor: event.floorName));
    }
  }

  Future<void> _onSave(
    SaveLocationSettingsEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationSettingsLoaded) {
      // Check if location has changed
      final oldPlace = locationConfigService.place;
      final oldBuilding = locationConfigService.building;
      final oldFloor = locationConfigService.floor;

      final newPlace = currentState.selectedPlace;
      final newBuilding = currentState.selectedBuilding;
      final newFloor = currentState.selectedFloor;

      final locationChanged =
          oldPlace != newPlace ||
          oldBuilding != newBuilding ||
          oldFloor != newFloor;

      // Save the new config
      await locationConfigService.saveConfig(
        place: newPlace,
        building: newBuilding,
        floor: newFloor,
      );

      // If location changed, invalidate caches for the old location
      if (locationChanged) {
        await Future.wait([
          floorPlanCacheService.clearCache(
            place: oldPlace,
            building: oldBuilding,
            floor: oldFloor,
          ),
          destinationsCacheService.clearCache(
            place: oldPlace,
            building: oldBuilding,
            floor: oldFloor,
            multiFloor: locationConfigService.multiFloorNavigation,
          ),
        ]);
      }
    }
  }
}
