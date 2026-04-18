import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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

  const ArNavigationTracking({
    this.currentPose,
    required this.state,
    required this.trackedPath,
    required this.nextWaypointIndex,
    required this.remainingDistancePx,
    required this.distanceToNextWaypointPx,
    this.guidanceMessage,
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
  ];
}
