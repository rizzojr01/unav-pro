import 'package:equatable/equatable.dart';

abstract class FloorMapEvent extends Equatable {
  const FloorMapEvent();

  @override
  List<Object?> get props => [];
}

class FloorMapInitialized extends FloorMapEvent {
  final String? initialFloor;

  const FloorMapInitialized({this.initialFloor});

  @override
  List<Object?> get props => [initialFloor];
}

class FloorMapFloorChanged extends FloorMapEvent {
  final String floor;

  const FloorMapFloorChanged(this.floor);

  @override
  List<Object?> get props => [floor];
}

class FloorMapLocationSelected extends FloorMapEvent {
  final double x;
  final double y;

  const FloorMapLocationSelected(this.x, this.y);

  @override
  List<Object?> get props => [x, y];
}

class FloorMapMarkerConfirmed extends FloorMapEvent {
  const FloorMapMarkerConfirmed();
}
