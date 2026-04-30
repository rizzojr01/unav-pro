import '../entities/ar_pose.dart';
import '../entities/localized_pose.dart';

/// Converts an ARKit camera pose into floorplan pixel coordinates.
///
/// Coordinate systems (with ARKit worldAlignment = .gravityAndHeading):
///
///   AR world frame (right-handed, gravity + compass aligned):
///     +X = geographic East
///     −Z = geographic North  (+Z = South)
///     +Y = up
///
///   Native → Dart mapping (AppDelegate.swift):
///     pose.x = worldX          (East,   metres)
///     pose.y = −worldZ         (North,  metres — positive = North)
///     pose.z = worldY          (Height, metres)
///
///   Floorplan (image) frame:
///     +X = East  (pixels right)
///     +Y = South (pixels down)
///
/// Because gravityAndHeading already aligns AR world axes with the real-world
/// compass, NO additional rotation is needed — only a unit conversion and a
/// sign flip for the North→South axis.
class ArPoseTransformer {
  const ArPoseTransformer();

  LocalizedPose transform({
    required ArPose currentArPose,
    required ArPose originArPose,
    required LocalizedPose referenceFloorplanPose,
    required double metersPerPixel,
  }) {
    // Displacement from the AR session anchor (metres, compass-aligned).
    final deltaEast  = currentArPose.x - originArPose.x; // East  (m)
    final deltaNorth = currentArPose.y - originArPose.y; // North (m)

    // Convert to floorplan pixels.
    // East  → FP +X (same direction).
    // North → FP −Y (FP +Y is South, so North flips sign).
    final fpDeltaX =  deltaEast  / metersPerPixel;
    final fpDeltaY = -deltaNorth / metersPerPixel;

    // Convert heading.
    // AR:  0 = East, increases counter-clockwise.
    // FP:  0 = East, increases clockwise.
    // → FP heading = −AR heading (mod 360).
    final fpHeading = _normalizeDegrees(-currentArPose.heading);

    return LocalizedPose(
      floorKey: referenceFloorplanPose.floorKey,
      x: referenceFloorplanPose.x + fpDeltaX,
      y: referenceFloorplanPose.y + fpDeltaY,
      z: currentArPose.z,
      heading: fpHeading,
      confidence: currentArPose.confidence,
      timestamp: currentArPose.timestamp,
    );
  }

  double _normalizeDegrees(double value) {
    var normalized = value % 360.0;
    if (normalized < 0) normalized += 360.0;
    return normalized;
  }
}
