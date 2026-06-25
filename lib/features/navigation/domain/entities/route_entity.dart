import 'dart:ui';

import '../../../../core/base/base_entity.dart';
import 'navigation_step_entity.dart';
import 'multi_floor_navigation_step_entity.dart';
import 'location_entity.dart';

/// Describes a single floor change in a multi-floor route.
///
/// Backend doesn't tag transition type (stair/elevator/ramp), so [kind] is
/// always [FloorTransitionKind.unknown] for now. Coordinates are in each
/// floor's own pixel space — `exitPoint` is on `fromFloor`, `entryPoint` is on
/// `toFloor`.
class FloorTransition {
  final String fromFloor;
  final String toFloor;
  final Offset exitPoint;
  final Offset entryPoint;
  final int fromFloorIndex;
  final int toFloorIndex;
  final FloorTransitionKind kind;

  const FloorTransition({
    required this.fromFloor,
    required this.toFloor,
    required this.exitPoint,
    required this.entryPoint,
    required this.fromFloorIndex,
    required this.toFloorIndex,
    this.kind = FloorTransitionKind.unknown,
  });
}

enum FloorTransitionKind { stair, elevator, ramp, unknown }

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

  /// Flat list of all steps across all floors
  List<NavigationStepEntity> get steps =>
      multiFloorSteps.expand((floor) => floor.steps).toList();

  /// Start location of the route
  LocationEntity get origin =>
      steps.isEmpty ? const LocationEntity(x: 0, y: 0) : steps.first.from;

  /// End location of the route
  LocationEntity get destination =>
      steps.isEmpty ? const LocationEntity(x: 0, y: 0) : steps.last.to;

  /// Inferred floor transitions, in order of traversal. A transition is the
  /// boundary between adjacent entries in [multiFloorSteps]: `exitPoint` is
  /// the last `to` on the leaving floor, `entryPoint` is the first `from` on
  /// the arriving floor.
  List<FloorTransition> get floorTransitions {
    final transitions = <FloorTransition>[];
    for (var i = 0; i < multiFloorSteps.length - 1; i++) {
      final fromGroup = multiFloorSteps[i];
      final toGroup = multiFloorSteps[i + 1];
      if (fromGroup.steps.isEmpty || toGroup.steps.isEmpty) continue;
      final exit = fromGroup.steps.last.to;
      final entry = toGroup.steps.first.from;
      transitions.add(
        FloorTransition(
          fromFloor: fromGroup.floor,
          toFloor: toGroup.floor,
          exitPoint: Offset(exit.x, exit.y),
          entryPoint: Offset(entry.x, entry.y),
          fromFloorIndex: i,
          toFloorIndex: i + 1,
        ),
      );
    }
    return transitions;
  }

  @override
  String? get id => entityId;

  @override
  List<Object?> get props =>
      [entityId, multiFloorSteps, metersPerPixel, routeNetworkSegments];
}
