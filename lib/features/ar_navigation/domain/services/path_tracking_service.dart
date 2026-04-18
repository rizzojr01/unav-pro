import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../entities/localized_pose.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';

enum ArTrackingState { idle, localizing, tracking, offRoute, arrived }

class ArTrackingUpdate {
  final List<Offset> trackedPath;
  final int nextWaypointIndex;
  final double remainingDistancePx;
  final double distanceToNextWaypointPx;
  final double distanceToPathPx;
  final double offRouteSeverity;
  final ArTrackingState state;
  final LocalizedPose? localizedPose;

  const ArTrackingUpdate({
    required this.trackedPath,
    required this.nextWaypointIndex,
    required this.remainingDistancePx,
    required this.distanceToNextWaypointPx,
    required this.distanceToPathPx,
    required this.offRouteSeverity,
    required this.state,
    this.localizedPose,
  });
}

class PathTrackingService {
  static const double _offRouteThresholdMeters = 2.0;
  static const double _turnNowThresholdMeters = 0.95;

  const PathTrackingService();

  ArTrackingUpdate update({
    required LocalizedPose? pose,
    required LocalizedPose? anchor,
    required RouteEntity route,
    required double metersPerPixel,
    required int previousWaypointIndex,
  }) {
    if (pose == null || anchor == null || route.steps.isEmpty) {
      final points = route.steps
          .map((s) => Offset(s.from.x, s.from.y))
          .toList();
      points.add(Offset(route.steps.last.to.x, route.steps.last.to.y));

      return ArTrackingUpdate(
        trackedPath: points,
        nextWaypointIndex: 0,
        remainingDistancePx: _measurePathDistance(points),
        distanceToNextWaypointPx: 0,
        distanceToPathPx: 0,
        offRouteSeverity: 0,
        state: ArTrackingState.localizing,
        localizedPose: pose,
      );
    }

    final currentPoint = Offset(pose.x, pose.y);
    final routePoints = route.steps
        .map((s) => Offset(s.from.x, s.from.y))
        .toList();
    routePoints.add(Offset(route.steps.last.to.x, route.steps.last.to.y));

    final fixedPolyline = <Offset>[Offset(anchor.x, anchor.y), ...routePoints];

    final offRouteThresholdPx = _offRouteThresholdMeters / metersPerPixel;
    final turnNowThresholdPx = _turnNowThresholdMeters / metersPerPixel;

    final projection = _projectToPath(fixedPolyline, currentPoint);
    final projectedWaypointIndex = projection.segmentIndex.clamp(
      0,
      routePoints.length - 1,
    );

    var activeWaypointIndex = projectedWaypointIndex;
    if (activeWaypointIndex < routePoints.length - 1 &&
        (routePoints[activeWaypointIndex] - currentPoint).distance <=
            turnNowThresholdPx) {
      activeWaypointIndex += 1;
    }

    // Ensure we don't go backwards in waypoints
    activeWaypointIndex = math.max(activeWaypointIndex, previousWaypointIndex);

    final trackedPath = <Offset>[
      currentPoint,
      ...routePoints.skip(activeWaypointIndex),
    ];

    final distanceToNextWaypointPx =
        (routePoints[activeWaypointIndex] - currentPoint).distance;
    final offRouteSeverity = (projection.distanceToPathPx / offRouteThresholdPx)
        .clamp(0.0, 1.0);

    ArTrackingState state = ArTrackingState.tracking;
    if (projection.distanceToPathPx > offRouteThresholdPx) {
      state = ArTrackingState.offRoute;
    } else if (distanceToNextWaypointPx <= turnNowThresholdPx &&
        activeWaypointIndex == routePoints.length - 1) {
      state = ArTrackingState.arrived;
    }

    return ArTrackingUpdate(
      trackedPath: trackedPath,
      nextWaypointIndex: activeWaypointIndex,
      remainingDistancePx: _measurePathDistance(trackedPath),
      distanceToNextWaypointPx: distanceToNextWaypointPx,
      distanceToPathPx: projection.distanceToPathPx,
      offRouteSeverity: offRouteSeverity,
      state: state,
      localizedPose: pose,
    );
  }

  double _measurePathDistance(List<Offset> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  _PathProjection _projectToPath(List<Offset> path, Offset currentPose) {
    double bestDistanceSq = double.infinity;
    Offset bestProjection = path.first;
    int bestSegmentIndex = 0;

    for (int i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final ab = b - a;
      final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
      if (abLenSq <= 1e-6) continue;

      final ap = currentPose - a;
      final t = ((ap.dx * ab.dx) + (ap.dy * ab.dy)) / abLenSq;
      final clampedT = t.clamp(0.0, 1.0);
      final projection = Offset(
        a.dx + ab.dx * clampedT,
        a.dy + ab.dy * clampedT,
      );

      final dx = currentPose.dx - projection.dx;
      final dy = currentPose.dy - projection.dy;
      final distanceSq = dx * dx + dy * dy;

      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        bestProjection = projection;
        bestSegmentIndex = i;
      }
    }

    return _PathProjection(
      projectedPoint: bestProjection,
      segmentIndex: bestSegmentIndex,
      distanceToPathPx: math.sqrt(bestDistanceSq),
    );
  }
}

class _PathProjection {
  final Offset projectedPoint;
  final int segmentIndex;
  final double distanceToPathPx;

  const _PathProjection({
    required this.projectedPoint,
    required this.segmentIndex,
    required this.distanceToPathPx,
  });
}
