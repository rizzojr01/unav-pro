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
