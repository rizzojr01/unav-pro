import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sense/features/ar_navigation/domain/entities/localized_pose.dart';
import 'package:smart_sense/features/ar_navigation/domain/services/path_tracking_service.dart';
import 'package:smart_sense/features/navigation/domain/entities/location_entity.dart';
import 'package:smart_sense/features/navigation/domain/entities/multi_floor_navigation_step_entity.dart';
import 'package:smart_sense/features/navigation/domain/entities/navigation_step_entity.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';

void main() {
  // L-shaped route: (0,0) → (100,0) → (100,100). 1 px = 0.1 m.
  RouteEntity route() => const RouteEntity(
        entityId: 'r1',
        metersPerPixel: 0.1,
        multiFloorSteps: [
          MultiFloorNavigationStepEntity(
            floor: 'f1',
            steps: [
              NavigationStepEntity(
                from: LocationEntity(x: 0, y: 0),
                to: LocationEntity(x: 100, y: 0),
                distanceMeters: 10,
                distanceFeet: 33,
              ),
              NavigationStepEntity(
                from: LocationEntity(x: 100, y: 0),
                to: LocationEntity(x: 100, y: 100),
                distanceMeters: 10,
                distanceFeet: 33,
              ),
            ],
          ),
        ],
      );

  LocalizedPose pose(double x, double y) => LocalizedPose(
        floorKey: 'f1',
        x: x,
        y: y,
        z: 0,
        heading: 0,
        confidence: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      );

  test('drawn path joins the route at the nearest point, not the waypoint',
      () {
    const service = PathTrackingService();
    // User mid-first-hallway, 0.5 m off the line. Old behavior drew a
    // diagonal straight to the corner (100,0).
    final update = service.update(
      pose: pose(50, 5),
      anchor: pose(0, 0),
      route: route(),
      metersPerPixel: 0.1,
      previousWaypointIndex: 0,
    );
    expect(update.trackedPath[0], const Offset(50, 5));
    expect(update.trackedPath[1].dx, closeTo(50, 0.5),
        reason: 'must join the route perpendicular at (50,0)');
    expect(update.trackedPath[1].dy, closeTo(0, 0.5));
  });

  test('final stretch joins the last segment instead of beelining', () {
    const service = PathTrackingService();
    // User beside the second hallway, halfway to the destination.
    final update = service.update(
      pose: pose(97, 50),
      anchor: pose(0, 0),
      route: route(),
      metersPerPixel: 0.1,
      previousWaypointIndex: 2,
    );
    // Path: user → (100,50) on the segment → destination (100,100).
    expect(update.trackedPath[1].dx, closeTo(100, 0.5));
    expect(update.trackedPath[1].dy, closeTo(50, 0.5),
        reason: 'must not draw straight from user to destination');
    expect(update.trackedPath.last, const Offset(100, 100));
  });
}
