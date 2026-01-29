import 'package:flutter_bloc/flutter_bloc.dart';
import 'floor_map_event.dart';
import 'floor_map_state.dart';

class FloorMapBloc extends Bloc<FloorMapEvent, FloorMapState> {
  FloorMapBloc() : super(const FloorMapInitial()) {
    on<FloorMapInitialized>(_onInitialized);
    on<FloorMapTapped>(_onTapped);
    on<FloorMapMarkerConfirmed>(_onMarkerConfirmed);
  }

  // Floor plan bounds (example coordinates for a building)
  static const double minLat = 40.730500;
  static const double maxLat = 40.730700;
  static const double minLng = -73.935300;
  static const double maxLng = -73.935100;

  void _onInitialized(FloorMapInitialized event, Emitter<FloorMapState> emit) {
    emit(const FloorMapReady());
  }

  void _onTapped(FloorMapTapped event, Emitter<FloorMapState> emit) {
    // Convert tap position to coordinates
    final relativeX = event.position.dx / event.mapSize.width;
    final relativeY = event.position.dy / event.mapSize.height;

    final x = minLng + (maxLng - minLng) * relativeX; // longitude
    final y = minLat + (maxLat - minLat) * (1 - relativeY); // latitude

    emit(FloorMapMarkerPlaced(event.position, x, y));
  }

  void _onMarkerConfirmed(FloorMapMarkerConfirmed event, Emitter<FloorMapState> emit) {
    // This will be handled by the UI navigation
  }
}