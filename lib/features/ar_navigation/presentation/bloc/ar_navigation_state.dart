import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';

import '../../domain/entities/localized_pose.dart';
import '../../domain/services/path_tracking_service.dart';

abstract class ArNavigationState extends Equatable {
  const ArNavigationState();

  @override
  List<Object?> get props => [];
}

class ArNavigationInitial extends ArNavigationState {
  const ArNavigationInitial();
}

class ArNavigationTracking extends ArNavigationState {
  final LocalizedPose? currentPose;
  final ArTrackingState state;
  final List<Offset> trackedPath;
  final int nextWaypointIndex;
  final double remainingDistancePx;
  final double distanceToNextWaypointPx;
  final String? guidanceMessage;
  final double arTravelDistance;
  final String? activeFloorKey;

  const ArNavigationTracking({
    this.currentPose,
    required this.state,
    required this.trackedPath,
    required this.nextWaypointIndex,
    required this.remainingDistancePx,
    required this.distanceToNextWaypointPx,
    this.guidanceMessage,
    this.arTravelDistance = 0.0,
    this.activeFloorKey,
  });

  @override
  List<Object?> get props => [
    currentPose,
    state,
    trackedPath,
    nextWaypointIndex,
    remainingDistancePx,
    distanceToNextWaypointPx,
    guidanceMessage,
    arTravelDistance,
    activeFloorKey,
  ];
}

/// User has reached a floor transition (e.g. last point on floor 1 before
/// stairs). AR pose forwarding is paused. UI surfaces a re-localize CTA;
/// the existing relocalize flow restarts AR with the new-floor reference
/// pose, which exits this state automatically.
class ArNavigationAwaitingFloorChange extends ArNavigationState {
  final FloorTransition transition;
  final LocalizedPose lastPose;

  const ArNavigationAwaitingFloorChange({
    required this.transition,
    required this.lastPose,
  });

  String get fromFloor => transition.fromFloor;
  String get toFloor => transition.toFloor;

  @override
  List<Object?> get props => [transition.fromFloor, transition.toFloor, lastPose];
}
