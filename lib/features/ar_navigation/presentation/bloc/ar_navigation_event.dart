import 'package:equatable/equatable.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';
import '../../domain/entities/localized_pose.dart';
import '../../domain/entities/ar_pose.dart';

abstract class ArNavigationEvent extends Equatable {
  const ArNavigationEvent();

  @override
  List<Object?> get props => [];
}

class StartArTrackingEvent extends ArNavigationEvent {
  final LocalizedPose referencePose;
  final double metersPerPixel;
  final RouteEntity route;
  final double? capturedSensorHeading;

  const StartArTrackingEvent({
    required this.referencePose,
    required this.metersPerPixel,
    required this.route,
    this.capturedSensorHeading,
  });

  @override
  List<Object?> get props => [
    referencePose,
    metersPerPixel,
    route,
    capturedSensorHeading,
  ];
}

class StopArTrackingEvent extends ArNavigationEvent {}

class ArPoseUpdatedEvent extends ArNavigationEvent {
  final ArPose pose;

  const ArPoseUpdatedEvent(this.pose);

  @override
  List<Object?> get props => [pose];
}
