import 'package:equatable/equatable.dart';

abstract class LocationSettingsEvent extends Equatable {
  const LocationSettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadLocationSettingsEvent extends LocationSettingsEvent {
  const LoadLocationSettingsEvent();
}

class SelectPlaceEvent extends LocationSettingsEvent {
  final String placeName;

  const SelectPlaceEvent(this.placeName);

  @override
  List<Object?> get props => [placeName];
}

class SelectBuildingEvent extends LocationSettingsEvent {
  final String buildingName;

  const SelectBuildingEvent(this.buildingName);

  @override
  List<Object?> get props => [buildingName];
}

class SelectFloorEvent extends LocationSettingsEvent {
  final String floorName;

  const SelectFloorEvent(this.floorName);

  @override
  List<Object?> get props => [floorName];
}

class SaveLocationSettingsEvent extends LocationSettingsEvent {
  const SaveLocationSettingsEvent();
}

/// Triggers GPS-based auto-detection of place + building
class AutoDetectByGpsEvent extends LocationSettingsEvent {
  const AutoDetectByGpsEvent();
}

/// Triggers Wi-Fi BSSID-based auto-detection of place + building
class AutoDetectByWifiEvent extends LocationSettingsEvent {
  const AutoDetectByWifiEvent();
}

/// Saves the current Wi-Fi BSSID → current place/building mapping
class SaveWifiMappingEvent extends LocationSettingsEvent {
  const SaveWifiMappingEvent();
}

/// Saves the user's current GPS coordinates → current place/building mapping
class SaveGpsMappingEvent extends LocationSettingsEvent {
  const SaveGpsMappingEvent();
}
