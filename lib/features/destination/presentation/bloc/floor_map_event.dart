import 'dart:ui';
import 'package:equatable/equatable.dart';

abstract class FloorMapEvent extends Equatable {
  const FloorMapEvent();

  @override
  List<Object?> get props => [];
}

class FloorMapInitialized extends FloorMapEvent {
  const FloorMapInitialized();
}

class FloorMapTapped extends FloorMapEvent {
  final Offset position;
  final Size mapSize;

  const FloorMapTapped(this.position, this.mapSize);

  @override
  List<Object?> get props => [position, mapSize];
}

class FloorMapMarkerConfirmed extends FloorMapEvent {
  const FloorMapMarkerConfirmed();
}