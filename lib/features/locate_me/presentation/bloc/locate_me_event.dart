import 'package:equatable/equatable.dart';

import '../../../destination/domain/entities/destination_entity.dart';

abstract class LocateMeEvent extends Equatable {
  const LocateMeEvent();

  @override
  List<Object?> get props => [];
}

/// Event to capture photo and start localization
class StartLocalizationEvent extends LocateMeEvent {
  final String capturedImagePath;

  const StartLocalizationEvent({required this.capturedImagePath});

  @override
  List<Object?> get props => [capturedImagePath];
}

/// Event to capture photo for preview
class LocateMeCapturePhotoEvent extends LocateMeEvent {
  final String capturedImagePath;

  const LocateMeCapturePhotoEvent({required this.capturedImagePath});

  @override
  List<Object?> get props => [capturedImagePath];
}

/// Event to start localization with sample image (for testing)
class StartLocalizationWithSampleEvent extends LocateMeEvent {
  const StartLocalizationWithSampleEvent();
}

/// Event to start localization with manual coordinates (floor plan selection)
class StartLocalizationWithCoordinatesEvent extends LocateMeEvent {
  final double x;
  final double y;

  const StartLocalizationWithCoordinatesEvent({
    required this.x,
    required this.y,
  });

  @override
  List<Object?> get props => [x, y];
}

/// Event to select a destination from the floor plan
class SelectDestinationEvent extends LocateMeEvent {
  final DestinationEntity destination;

  const SelectDestinationEvent({required this.destination});

  @override
  List<Object?> get props => [destination];
}

/// Event to clear selected destination
class ClearSelectedDestinationEvent extends LocateMeEvent {
  const ClearSelectedDestinationEvent();
}

/// Event to navigate to selected destination
class NavigateToDestinationEvent extends LocateMeEvent {
  final DestinationEntity destination;

  const NavigateToDestinationEvent({required this.destination});

  @override
  List<Object?> get props => [destination];
}

/// Event to reset the locate me flow
class ResetLocateMeEvent extends LocateMeEvent {
  const ResetLocateMeEvent();
}
