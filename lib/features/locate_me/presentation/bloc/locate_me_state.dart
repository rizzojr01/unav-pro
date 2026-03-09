import '../../../../core/base/base_state.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/floor_plan_entity.dart';
import '../../domain/entities/user_position_entity.dart';

abstract class LocateMeState extends BaseState {
  const LocateMeState();
}

/// Initial state - waiting for camera capture
class LocateMeInitial extends LocateMeState {
  const LocateMeInitial();
}

/// State when camera is ready for capture
class LocateMeCameraReady extends LocateMeState {
  const LocateMeCameraReady();
}

/// State when photo is captured for preview
class LocateMePhotoCaptured extends LocateMeState {
  final String imagePath;
  final String? floor;
  final double? heading;

  const LocateMePhotoCaptured(this.imagePath, {this.floor, this.heading});

  @override
  List<Object?> get props => [imagePath, floor, heading];
}

/// State when processing localization
class LocateMeLoading extends LocateMeState {
  final String message;

  const LocateMeLoading({this.message = 'Analyzing your location...'});

  @override
  List<Object?> get props => [message];
}

/// State when floor plan and user position are ready
class LocateMeReady extends LocateMeState {
  final FloorPlanEntity floorPlan;
  final UserPositionEntity userPosition;
  final List<DestinationEntity> destinations;
  final DestinationEntity? selectedDestination;
  final bool isManualLocalization;
  final String? floor;

  const LocateMeReady({
    required this.floorPlan,
    required this.userPosition,
    required this.destinations,
    this.selectedDestination,
    this.isManualLocalization = false,
    this.floor,
  });

  LocateMeReady copyWith({
    FloorPlanEntity? floorPlan,
    UserPositionEntity? userPosition,
    List<DestinationEntity>? destinations,
    DestinationEntity? selectedDestination,
    bool? isManualLocalization,
    bool clearSelectedDestination = false,
    String? floor,
  }) {
    return LocateMeReady(
      floorPlan: floorPlan ?? this.floorPlan,
      userPosition: userPosition ?? this.userPosition,
      destinations: destinations ?? this.destinations,
      isManualLocalization: isManualLocalization ?? this.isManualLocalization,
      selectedDestination: clearSelectedDestination
          ? null
          : (selectedDestination ?? this.selectedDestination),
      floor: floor ?? this.floor,
    );
  }

  @override
  List<Object?> get props => [
    floorPlan,
    userPosition,
    destinations,
    selectedDestination,
    isManualLocalization,
    floor,
  ];
}

/// Error state
class LocateMeError extends LocateMeState {
  final String message;

  const LocateMeError(this.message);

  @override
  List<Object?> get props => [message];
}
