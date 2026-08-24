import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sense/features/ar_navigation/domain/entities/ar_pose.dart';
import 'package:smart_sense/features/ar_navigation/domain/entities/localized_pose.dart';
import 'package:smart_sense/features/ar_navigation/domain/services/direction_bucket_tracker.dart';

void main() {
  // L-shaped corridor: hallway 1 runs East (0,0)→(100,0), hallway 2 runs
  // South (100,0)→(100,100). 1 px = 0.1 m.
  const mpp = 0.1;
  const segments = [
    (Offset(0, 0), Offset(100, 0)),
    (Offset(100, 0), Offset(100, 100)),
  ];
  ArPose pose(double east, double south) => ArPose(
        x: east,
        y: -south,
        z: 0,
        heading: 0,
        confidence: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        worldX: east,
        worldZ: south,
      );

  LocalizedPose ref() => LocalizedPose(
        floorKey: 'f1',
        x: 0,
        y: 0,
        z: 0,
        heading: 0,
        confidence: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      );

  LocalizedPose drive(DirectionBucketTracker tracker, ArPose p) =>
      tracker.track(
        currentArPose: p,
        referenceFp: ref(),
        sumHeadingDeg: 0,
        metersPerPixel: mpp,
        segments: segments,
      );

  test('survives a turn even when yaw drift mis-buckets the walk direction',
      () {
    final tracker = DirectionBucketTracker();
    drive(tracker, pose(0, 0)); // anchor

    // Walk 10 m East to the corner (fpAngle 0° with sumHeadingDeg 0).
    var east = 0.0;
    late LocalizedPose out;
    for (var i = 0; i < 20; i++) {
      east += 0.5;
      out = drive(tracker, pose(east, 0));
    }
    expect(out.x, closeTo(100, 1));
    expect(out.y, closeTo(0, 1));

    // Now walk South, but with 50° of ARKit yaw drift: the AR walk vector
    // reads 40° instead of 90° in floorplan frame — compass bucket4 would
    // pick East and pin the dot on the corner forever.
    var south = 0.0;
    for (var i = 0; i < 10; i++) {
      east += 0.5 * 0.766; // cos(40°) drift components
      south += 0.5 * 0.643; // sin(40°) — wrong-looking, deliberately
      out = drive(tracker, pose(east, south));
    }
    // With the track-direction fix the dot must have advanced down hallway 2.
    expect(out.x, closeTo(100, 1));
    expect(out.y, greaterThan(20),
        reason: 'dot must progress down the second hallway, not pin at corner');
  });

  test('snapToRoute=false lets the dot leave the corridor freely', () {
    final tracker = DirectionBucketTracker();
    LocalizedPose free(ArPose p) => tracker.track(
          currentArPose: p,
          referenceFp: ref(),
          sumHeadingDeg: 0,
          metersPerPixel: mpp,
          segments: segments,
          snapToRoute: false,
        );

    free(pose(0, 0)); // anchor
    // Walk 45° diagonal, straight off the corridor.
    var out = free(pose(2, 2));
    expect(out.x, closeTo(20, 0.5)); // 2m East = 20px
    expect(out.y, closeTo(20, 0.5),
        reason: 'dot must follow the raw walk, not snap to a corridor');
  });

  test('relocalization jump does not teleport the dot', () {
    final tracker = DirectionBucketTracker();
    drive(tracker, pose(0, 0)); // anchor
    var out = drive(tracker, pose(1, 0)); // 1 m East
    final beforeX = out.x;

    out = drive(tracker, pose(6, 0)); // 5 m snap — ARKit relocalized
    expect(out.x, beforeX, reason: 'jump must be consumed, not walked');

    // Normal stepping resumes from the new anchor.
    out = drive(tracker, pose(6.5, 0));
    expect(out.x, greaterThan(beforeX));
  });
}
