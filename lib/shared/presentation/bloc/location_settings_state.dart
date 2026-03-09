import 'package:equatable/equatable.dart';

import '../../domain/entities/place_entity.dart';

/// Status of GPS/Wi-Fi auto-detection
enum AutoDetectStatus { idle, detecting, detected, failed }

abstract class LocationSettingsState extends Equatable {
  const LocationSettingsState();

  @override
  List<Object?> get props => [];
}

class LocationSettingsInitial extends LocationSettingsState {
  const LocationSettingsInitial();
}

class LocationSettingsLoading extends LocationSettingsState {
  const LocationSettingsLoading();
}

class LocationSettingsLoaded extends LocationSettingsState {
  final List<PlaceEntity> places;
  final String selectedPlace;
  final String selectedBuilding;
  final String selectedFloor;
  final AutoDetectStatus autoDetectStatus;
  final String? autoDetectMessage;
  final bool isSyncing;
  final String? syncMessage;

  const LocationSettingsLoaded({
    required this.places,
    required this.selectedPlace,
    required this.selectedBuilding,
    required this.selectedFloor,
    this.autoDetectStatus = AutoDetectStatus.idle,
    this.autoDetectMessage,
    this.isSyncing = false,
    this.syncMessage,
  });

  @override
  List<Object?> get props => [
    places,
    selectedPlace,
    selectedBuilding,
    selectedFloor,
    autoDetectStatus,
    autoDetectMessage,
    isSyncing,
    syncMessage,
  ];

  /// Get the selected place entity
  PlaceEntity? get currentPlace {
    try {
      return places.firstWhere((p) => p.name == selectedPlace);
    } catch (_) {
      return places.isNotEmpty ? places.first : null;
    }
  }

  /// Get the selected building entity
  BuildingEntity? get currentBuilding {
    final place = currentPlace;
    if (place == null) return null;
    try {
      return place.buildings.firstWhere((b) => b.name == selectedBuilding);
    } catch (_) {
      return place.buildings.isNotEmpty ? place.buildings.first : null;
    }
  }

  /// Get the selected floor entity
  FloorEntity? get currentFloor {
    final building = currentBuilding;
    if (building == null) return null;
    try {
      return building.floors.firstWhere((f) => f.name == selectedFloor);
    } catch (_) {
      return building.floors.isNotEmpty ? building.floors.first : null;
    }
  }

  LocationSettingsLoaded copyWith({
    List<PlaceEntity>? places,
    String? selectedPlace,
    String? selectedBuilding,
    String? selectedFloor,
    AutoDetectStatus? autoDetectStatus,
    String? autoDetectMessage,
    bool? isSyncing,
    String? syncMessage,
  }) {
    return LocationSettingsLoaded(
      places: places ?? this.places,
      selectedPlace: selectedPlace ?? this.selectedPlace,
      selectedBuilding: selectedBuilding ?? this.selectedBuilding,
      selectedFloor: selectedFloor ?? this.selectedFloor,
      autoDetectStatus: autoDetectStatus ?? this.autoDetectStatus,
      autoDetectMessage: autoDetectMessage,
      isSyncing: isSyncing ?? this.isSyncing,
      syncMessage: syncMessage ?? this.syncMessage,
    );
  }
}

class LocationSettingsError extends LocationSettingsState {
  final String message;

  const LocationSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
