import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/api_routes.dart';
import '../../data/datasources/place_remote_datasource.dart';
import '../../domain/entities/gps_mapping_entity.dart';
import '../../domain/entities/wifi_mapping_entity.dart';
import '../../services/destinations_cache_service.dart';
import '../../services/floor_plan_cache_service.dart';
import '../../services/gps_auto_select_service.dart';
import '../../services/location_config_service.dart';
import '../../services/location_service.dart';
import '../../services/wifi_auto_select_service.dart';
import '../../services/map_download_service.dart';
import 'location_settings_event.dart';
import 'location_settings_state.dart';

class LocationSettingsBloc
    extends Bloc<LocationSettingsEvent, LocationSettingsState> {
  final PlaceRemoteDataSource placeRemoteDataSource;
  final LocationConfigService locationConfigService;
  final FloorPlanCacheService floorPlanCacheService;
  final DestinationsCacheService destinationsCacheService;
  final GpsAutoSelectService gpsAutoSelectService;
  final WifiAutoSelectService wifiAutoSelectService;
  final LocationService locationService;
  final MapDownloadService mapDownloadService;

  LocationSettingsBloc({
    required this.placeRemoteDataSource,
    required this.locationConfigService,
    required this.floorPlanCacheService,
    required this.destinationsCacheService,
    required this.gpsAutoSelectService,
    required this.wifiAutoSelectService,
    required this.locationService,
    required this.mapDownloadService,
  }) : super(const LocationSettingsInitial()) {
    on<LoadLocationSettingsEvent>(_onLoad);
    on<SelectPlaceEvent>(_onSelectPlace);
    on<SelectBuildingEvent>(_onSelectBuilding);
    on<SelectFloorEvent>(_onSelectFloor);
    on<SaveLocationSettingsEvent>(_onSave);
    on<AutoDetectByGpsEvent>(_onAutoDetectByGps);
    on<AutoDetectByWifiEvent>(_onAutoDetectByWifi);
    on<SaveWifiMappingEvent>(_onSaveWifiMapping);
    on<SaveGpsMappingEvent>(_onSaveGpsMapping);
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
          autoDetectStatus: AutoDetectStatus.idle,
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
          autoDetectStatus: AutoDetectStatus.idle,
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
      final oldPlace = locationConfigService.place;
      final oldBuilding = locationConfigService.building;

      final newPlace = currentState.selectedPlace;
      final newBuilding = currentState.selectedBuilding;
      final newFloor = currentState.selectedFloor;

      final buildingChanged =
          oldPlace != newPlace || oldBuilding != newBuilding;

      // Save the new config
      await locationConfigService.saveConfig(
        place: newPlace,
        building: newBuilding,
        floor: newFloor,
      );

      // Whenever the building changes, download all floor maps fresh.
      // This clears the old cache and pre-fetches every floor plan so
      // LocateMeBloc and NavigationBloc can read from cache without
      // individual per-floor API calls.
      if (buildingChanged) {
        // Clear destinations cache for the old building
        await destinationsCacheService.clearAllCache();

        emit(
          currentState.copyWith(
            isSyncing: true,
            syncMessage: 'Downloading maps for $newBuilding…',
          ),
        );

        final result = await mapDownloadService.syncMapsForBuilding(
          place: newPlace,
          building: newBuilding,
          baseUrl: ApiRoutes.baseUrl,
          force: true,
        );

        emit(
          currentState.copyWith(
            isSyncing: false,
            syncMessage: result.success
                ? 'Maps ready (${result.downloadedFloors.length} floors)'
                : 'Map sync failed: ${result.errorMessage}',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GPS Auto-Detection
  // ---------------------------------------------------------------------------

  Future<void> _onAutoDetectByGps(
    AutoDetectByGpsEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LocationSettingsLoaded) return;

    emit(
      currentState.copyWith(
        autoDetectStatus: AutoDetectStatus.detecting,
        autoDetectMessage: 'Detecting location via GPS…',
      ),
    );

    try {
      final result = await gpsAutoSelectService.detectNearestBuilding(
        currentState.places,
      );

      if (result == null) {
        emit(
          currentState.copyWith(
            autoDetectStatus: AutoDetectStatus.failed,
            autoDetectMessage:
                'No nearby building found. Move closer to a building.',
          ),
        );
        return;
      }

      // Auto-select the matched place and building
      // Only reset floor if place or building actually changed
      final placeChanged = result.place != currentState.selectedPlace;
      final buildingChanged = result.building != currentState.selectedBuilding;

      String selectedFloor = currentState.selectedFloor;
      if (placeChanged || buildingChanged) {
        final matchedPlace = currentState.places
            .where((p) => p.name == result.place)
            .firstOrNull;
        final matchedBuilding = matchedPlace?.buildings
            .where((b) => b.name == result.building)
            .firstOrNull;
        final firstFloor =
            matchedBuilding != null && matchedBuilding.floors.isNotEmpty
            ? matchedBuilding.floors.first
            : null;
        selectedFloor = firstFloor?.name ?? currentState.selectedFloor;
      }

      emit(
        currentState.copyWith(
          selectedPlace: result.place,
          selectedBuilding: result.building,
          selectedFloor: selectedFloor,
          autoDetectStatus: AutoDetectStatus.detected,
          autoDetectMessage: 'Detected: ${result.place} → ${result.building}',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.failed,
          autoDetectMessage: 'GPS detection failed: ${e.toString()}',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Wi-Fi Auto-Detection
  // ---------------------------------------------------------------------------

  Future<void> _onAutoDetectByWifi(
    AutoDetectByWifiEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LocationSettingsLoaded) return;

    emit(
      currentState.copyWith(
        autoDetectStatus: AutoDetectStatus.detecting,
        autoDetectMessage: 'Detecting location via Wi-Fi…',
      ),
    );

    try {
      final bssid = await wifiAutoSelectService.getCurrentBssid();

      if (bssid == null) {
        emit(
          currentState.copyWith(
            autoDetectStatus: AutoDetectStatus.failed,
            autoDetectMessage:
                'Not connected to Wi-Fi or BSSID unavailable. Check permissions.',
          ),
        );
        return;
      }

      final mapping = wifiAutoSelectService.getMappingForBssid(bssid);

      if (mapping == null) {
        final ssid = await wifiAutoSelectService.getCurrentSsid();
        emit(
          currentState.copyWith(
            autoDetectStatus: AutoDetectStatus.failed,
            autoDetectMessage:
                'No mapping found for "${ssid ?? bssid}". '
                'Select place/building manually, then tap "Save Wi-Fi Mapping".',
          ),
        );
        return;
      }

      // Auto-select the matched place and building
      // Only reset floor if place or building actually changed
      final placeChanged = mapping.placeName != currentState.selectedPlace;
      final buildingChanged =
          mapping.buildingName != currentState.selectedBuilding;

      String selectedFloor = currentState.selectedFloor;
      if (placeChanged || buildingChanged) {
        final matchedPlace = currentState.places
            .where((p) => p.name == mapping.placeName)
            .firstOrNull;
        final matchedBuilding = matchedPlace?.buildings
            .where((b) => b.name == mapping.buildingName)
            .firstOrNull;
        final firstFloor =
            matchedBuilding != null && matchedBuilding.floors.isNotEmpty
            ? matchedBuilding.floors.first
            : null;
        selectedFloor = firstFloor?.name ?? currentState.selectedFloor;
      }

      emit(
        currentState.copyWith(
          selectedPlace: mapping.placeName,
          selectedBuilding: mapping.buildingName,
          selectedFloor: selectedFloor,
          autoDetectStatus: AutoDetectStatus.detected,
          autoDetectMessage:
              'Detected via Wi-Fi: ${mapping.placeName} → ${mapping.buildingName}',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.failed,
          autoDetectMessage: 'Wi-Fi detection failed: ${e.toString()}',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Save Wi-Fi Mapping
  // ---------------------------------------------------------------------------

  Future<void> _onSaveWifiMapping(
    SaveWifiMappingEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LocationSettingsLoaded) return;

    try {
      final bssid = await wifiAutoSelectService.getCurrentBssid();
      if (bssid == null) {
        emit(
          currentState.copyWith(
            autoDetectStatus: AutoDetectStatus.failed,
            autoDetectMessage:
                'Cannot save: not connected to Wi-Fi or BSSID unavailable.',
          ),
        );
        return;
      }

      final ssid = await wifiAutoSelectService.getCurrentSsid() ?? '';

      final mapping = WifiMappingEntity(
        bssid: bssid,
        ssid: ssid,
        placeName: currentState.selectedPlace,
        buildingName: currentState.selectedBuilding,
        createdAt: DateTime.now(),
      );

      await wifiAutoSelectService.saveMapping(mapping);

      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.detected,
          autoDetectMessage:
              'Saved Wi-Fi mapping: "$ssid" → '
              '${currentState.selectedPlace} / ${currentState.selectedBuilding}',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.failed,
          autoDetectMessage: 'Failed to save mapping: ${e.toString()}',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Save GPS Mapping
  // ---------------------------------------------------------------------------

  Future<void> _onSaveGpsMapping(
    SaveGpsMappingEvent event,
    Emitter<LocationSettingsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! LocationSettingsLoaded) return;

    try {
      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.detecting,
          autoDetectMessage: 'Saving GPS location…',
        ),
      );

      final position = await locationService.getCurrentLocation();

      final mapping = GpsMappingEntity(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: 150.0,
        placeName: currentState.selectedPlace,
        buildingName: currentState.selectedBuilding,
        createdAt: DateTime.now(),
      );

      await gpsAutoSelectService.saveMapping(mapping);

      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.detected,
          autoDetectMessage:
              'Saved GPS location for '
              '${currentState.selectedPlace} / ${currentState.selectedBuilding}',
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          autoDetectStatus: AutoDetectStatus.failed,
          autoDetectMessage: 'Failed to save GPS location: ${e.toString()}',
        ),
      );
    }
  }
}
