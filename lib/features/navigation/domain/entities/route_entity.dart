import 'dart:ui';

import '../../../../core/base/base_entity.dart';
import 'navigation_step_entity.dart';
import 'multi_floor_navigation_step_entity.dart';
import 'location_entity.dart';

class RouteEntity extends BaseEntity {
  final String entityId;
  final List<MultiFloorNavigationStepEntity> multiFloorSteps;
  final double? metersPerPixel;

  /// Full corridor graph in floorplan pixel coordinates. Each entry is a
  /// `(from, to)` pair representing one navigable edge. Used for snap-to-route.
  /// Empty list when the backend omits `route_segments`.
  final List<(Offset, Offset)> routeNetworkSegments;

  const RouteEntity({
    required this.entityId,
    required this.multiFloorSteps,
    this.metersPerPixel,
    this.routeNetworkSegments = const [],
  });

  /// Flat list of all steps across all floors.
  ///
  /// NOTE: coordinates from different floors live in different floorplan
  /// pixel frames — filter to a single floor (via [multiFloorSteps]) before
  /// projecting these points into AR/world space.
  List<NavigationStepEntity> get steps =>
      multiFloorSteps.expand((floor) => floor.steps).toList();

  /// Start location of the route
  LocationEntity get origin =>
      steps.isEmpty ? const LocationEntity(x: 0, y: 0) : steps.first.from;

  /// End location of the route
  LocationEntity get destination =>
      steps.isEmpty ? const LocationEntity(x: 0, y: 0) : steps.last.to;

  @override
  String? get id => entityId;

  @override
  List<Object?> get props =>
      [entityId, multiFloorSteps, metersPerPixel, routeNetworkSegments];
}
