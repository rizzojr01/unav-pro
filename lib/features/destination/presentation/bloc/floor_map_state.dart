import 'dart:ui';
import '../../../../core/base/base_state.dart';

abstract class FloorMapState extends BaseState {
  const FloorMapState();
}

class FloorMapInitial extends FloorMapState {
  const FloorMapInitial();
}

class FloorMapLoading extends FloorMapState {
  const FloorMapLoading();
}

class FloorMapReady extends FloorMapState {
  final Offset? markerPosition;
  final double? latitude;
  final double? longitude;

  const FloorMapReady({
    this.markerPosition,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [markerPosition, latitude, longitude];
}

class FloorMapMarkerPlaced extends FloorMapState {
  final Offset markerPosition;
  final double x; // longitude
  final double y; // latitude

  const FloorMapMarkerPlaced(this.markerPosition, this.x, this.y);

  @override
  List<Object?> get props => [markerPosition, x, y];
}

class FloorMapError extends FloorMapState {
  final String message;

  const FloorMapError(this.message);

  @override
  List<Object?> get props => [message];
}