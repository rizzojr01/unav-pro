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
  final String? base64FloorPlan;
  final List<String> availableFloors;
  final String selectedFloor;
  final double? x;
  final double? y;

  const FloorMapReady({
    this.base64FloorPlan,
    this.availableFloors = const [],
    this.selectedFloor = '',
    this.x,
    this.y,
  });

  @override
  List<Object?> get props => [
    base64FloorPlan,
    availableFloors,
    selectedFloor,
    x,
    y,
  ];

  FloorMapReady copyWith({
    String? base64FloorPlan,
    List<String>? availableFloors,
    String? selectedFloor,
    double? x,
    double? y,
  }) {
    return FloorMapReady(
      base64FloorPlan: base64FloorPlan ?? this.base64FloorPlan,
      availableFloors: availableFloors ?? this.availableFloors,
      selectedFloor: selectedFloor ?? this.selectedFloor,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

class FloorMapMarkerPlaced extends FloorMapState {
  final double x;
  final double y;

  const FloorMapMarkerPlaced(this.x, this.y);

  @override
  List<Object?> get props => [x, y];
}

class FloorMapError extends FloorMapState {
  final String message;

  const FloorMapError(this.message);

  @override
  List<Object?> get props => [message];
}
