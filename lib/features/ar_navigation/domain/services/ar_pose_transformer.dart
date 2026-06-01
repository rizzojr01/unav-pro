import 'dart:math' as math;

import '../entities/ar_pose.dart';
import '../entities/localized_pose.dart';

/// Converts an ARKit camera pose into floorplan pixel coordinates.
///
/// Mirrors the NavigationController._transformTrackedPose logic from ar_temp,
/// which uses a sumHeadingDeg rotation to bridge the AR world frame and the
/// floorplan image frame — making it work for any floorplan orientation, not
/// only North-up maps.
///
/// Coordinate systems:
///   AR world frame (ARKit worldAlignment = .gravityAndHeading):
///     +X = East, +Y = Up, +Z = South
///
///   Native → Dart mapping (AppDelegate.swift):
///     pose.x = worldX  (East, metres)
///     pose.y = −worldZ (North, metres — positive = North)
///     pose.z = worldY  (Height, metres)
///
///   Math plane (intermediate, Y-up 2D):
///     x = East  (worldX)
///     y = North (−worldZ)
///
///   Floorplan (image) frame:
///     +X = right (East at 0° heading)
///     +Y = down  (South at 0° heading)
///
///   image ↔ math plane: flip Y  (mathY = −imageY)
class ArPoseTransformer {
  const ArPoseTransformer();

  LocalizedPose transform({
    required ArPose currentArPose,
    required ArPose originArPose,
    required LocalizedPose referenceFloorplanPose,
    required double metersPerPixel,
    double headingOffsetDeg = 0.0,
  }) {
    // Extract planar (East, North) coordinates from each pose.
    final originArPoint = _extractArPlanarPoint(originArPose);
    final currentArPoint = _extractArPlanarPoint(currentArPose);

    final arDeltaX = currentArPoint.x - originArPoint.x; // East  delta (m)
    final arDeltaY = currentArPoint.y - originArPoint.y; // North delta (m)

    // sumHeadingDeg = the total rotation that maps AR world deltas onto the
    // floorplan math-plane. It combines:
    //   - reference.heading: camera bearing recorded in the floorplan frame
    //   - captureHeading: AR yaw at session start (0=East, CCW in AR world)
    //   - headingOffsetDeg: user-tunable calibration offset
    final captureHeading = _normalizeDegrees(originArPose.heading);
    final currentHeading = _normalizeDegrees(currentArPose.heading);
    final sumHeadingDeg = _normalizeDegrees(
      referenceFloorplanPose.heading + captureHeading + headingOffsetDeg,
    );
    final sumHeadingRad = sumHeadingDeg * math.pi / 180.0;

    // Rotate AR world deltas into the floorplan math-plane frame (CW rotation).
    final rotatedX =
        arDeltaX * math.cos(sumHeadingRad) + arDeltaY * math.sin(sumHeadingRad);
    final rotatedY =
        arDeltaY * math.cos(sumHeadingRad) - arDeltaX * math.sin(sumHeadingRad);

    final deltaFloorplanMathX = rotatedX / metersPerPixel;
    final deltaFloorplanMathY = rotatedY / metersPerPixel;

    // Reference point: image → math plane (flip Y).
    final refMathX = referenceFloorplanPose.x;
    final refMathY = -referenceFloorplanPose.y;

    final curMathX = refMathX + deltaFloorplanMathX;
    final curMathY = refMathY + deltaFloorplanMathY;

    // Math plane → image (flip Y back).
    final fpX = curMathX;
    final fpY = -curMathY;

    // Heading in floorplan space: subtract current AR heading from sumHeading.
    final fpHeading = _normalizeDegrees(sumHeadingDeg - currentHeading);

    return LocalizedPose(
      floorKey: referenceFloorplanPose.floorKey,
      x: fpX,
      y: fpY,
      z: currentArPose.z,
      heading: fpHeading,
      confidence: currentArPose.confidence,
      timestamp: currentArPose.timestamp,
    );
  }

  /// Extract a 2D math-plane point (East, North) from an AR pose.
  /// Uses worldX/worldZ when available, falls back to pose.x / −pose.y.
  math.Point<double> _extractArPlanarPoint(ArPose pose) {
    final worldX = pose.worldX ?? pose.x;
    final worldZ = pose.worldZ ?? -pose.y; // worldZ = South; −worldZ = North
    return math.Point<double>(worldX, -worldZ); // (East, North)
  }

  double _normalizeDegrees(double value) {
    var normalized = value % 360.0;
    if (normalized < 0) normalized += 360.0;
    return normalized;
  }
}
