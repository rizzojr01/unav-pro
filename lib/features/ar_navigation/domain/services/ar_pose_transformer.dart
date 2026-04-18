import 'dart:math' as math;
import '../entities/ar_pose.dart';
import '../entities/localized_pose.dart';

class ArPoseTransformer {
  const ArPoseTransformer();

  LocalizedPose transform({
    required ArPose currentArPose,
    required ArPose originArPose,
    required LocalizedPose referenceFloorplanPose,
    required double metersPerPixel,
  }) {
    final originArPoint = _extractArPlanarPoint(originArPose);
    final currentArPoint = _extractArPlanarPoint(currentArPose);

    final arDeltaX = currentArPoint.x - originArPoint.x;
    final arDeltaY = currentArPoint.y - originArPoint.y;

    final captureHeading = _normalizeDegrees(originArPose.heading);
    final currentHeading = _normalizeDegrees(currentArPose.heading);

    final sumHeadingDeg = _normalizeDegrees(
      referenceFloorplanPose.heading + captureHeading,
    );
    final sumHeadingRad = sumHeadingDeg * math.pi / 180.0;

    // Rotate the AR delta into floorplan space
    final rotatedX =
        (arDeltaX * math.cos(sumHeadingRad)) +
        (arDeltaY * math.sin(sumHeadingRad));
    final rotatedY =
        (arDeltaY * math.cos(sumHeadingRad)) -
        (arDeltaX * math.sin(sumHeadingRad));

    final deltaFloorplanMath = math.Point<double>(
      rotatedX / metersPerPixel,
      rotatedY / metersPerPixel,
    );

    // Reference floorplan point in math plane (y is inverted)
    final referenceFloorplanMath = math.Point<double>(
      referenceFloorplanPose.x,
      -referenceFloorplanPose.y,
    );

    final currentFloorplanMath = math.Point<double>(
      referenceFloorplanMath.x + deltaFloorplanMath.x,
      referenceFloorplanMath.y + deltaFloorplanMath.y,
    );

    // Convert back to image coordinates
    final currentFloorplanImage = math.Point<double>(
      currentFloorplanMath.x,
      -currentFloorplanMath.y,
    );

    return LocalizedPose(
      floorKey: referenceFloorplanPose.floorKey,
      x: currentFloorplanImage.x,
      y: currentFloorplanImage.y,
      z: currentArPose.z,
      heading: _normalizeDegrees(sumHeadingDeg - currentHeading),
      confidence: currentArPose.confidence,
      timestamp: currentArPose.timestamp,
    );
  }

  math.Point<double> _extractArPlanarPoint(ArPose pose) {
    // AR space: x is side, y is up, z is forward
    // Map to planar x, y: x = worldX, y = -worldZ (assuming y is up)
    return math.Point<double>(pose.x, -pose.z);
  }

  double _normalizeDegrees(double value) {
    var normalized = value % 360.0;
    if (normalized < 0) {
      normalized += 360.0;
    }
    return normalized;
  }
}
