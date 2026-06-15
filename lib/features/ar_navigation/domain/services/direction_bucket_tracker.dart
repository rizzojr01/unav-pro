import 'dart:math' as math;
import 'dart:ui';

import 'package:smart_sense/core/utils/route_snap.dart';

import '../entities/ar_pose.dart';
import '../entities/localized_pose.dart';

/// "Push train on tracks" tracker.
///
/// Implements Solution 2 from the design review: instead of trusting the
/// raw ARKit yaw (which carries 2–5° error), we take only the user's
/// ARKit walk vector (distance + rough direction), bin the direction into
/// 4 or 8 compass buckets, and advance the user's floorplan position
/// along the snap-to-route corridor in that bucketed direction.
///
/// Because each bucket spans ±45° (4-bucket) or ±22.5° (8-bucket), a yaw
/// error within the bucket width is silently absorbed — the user dot
/// still ends up moving "east" by the right number of metres.
///
/// Compass convention matches the floorplan image plane (image Y down):
///   East  = 0° / 360°  → buckets 315°–44.9°    → unit (+1,  0)
///   South = 90°        → buckets 45°–134.9°    → unit ( 0, +1)
///   West  = 180°       → buckets 135°–224.9°   → unit (-1,  0)
///   North = 270°       → buckets 225°–314.9°   → unit ( 0, -1)
///
/// Direction is derived from the *AR-world travel vector*, NOT the phone's
/// facing heading. So the user can walk sideways, backwards, or hold the
/// phone in any orientation and the bucket still tracks where their body
/// is actually going.
class DirectionBucketTracker {
  static const double _minStepMeters = 0.10;

  Offset? _lastFpPosition;
  ArPose? _lastArPose;

  /// 4 = N/E/S/W. 8 = N/NE/E/SE/S/SW/W/NW.
  int bucketCount;

  DirectionBucketTracker({this.bucketCount = 4});

  void reset() {
    _lastFpPosition = null;
    _lastArPose = null;
  }

  /// Returns the user's bucketed-direction position in floorplan space.
  ///
  /// On the first call (or after [reset]), the tracker anchors at
  /// [referenceFp] and returns it unchanged with [currentArPose]'s
  /// timestamp and confidence. The reported heading is the floorplan
  /// reference heading.
  ///
  /// On subsequent calls, the AR walk vector is bucketed and applied to
  /// the previously-snapped floorplan position. The result is then snapped
  /// onto the nearest [segments] within 2 m to keep the user on the path.
  LocalizedPose track({
    required ArPose currentArPose,
    required LocalizedPose referenceFp,
    required double sumHeadingDeg,
    required double metersPerPixel,
    required List<(Offset, Offset)> segments,
  }) {
    final lastFp = _lastFpPosition;
    final lastAr = _lastArPose;

    // Phone-facing floorplan heading. Mirrors ArPoseTransformer so the
    // returned LocalizedPose.heading rotates the map view in sync with
    // the phone, even though the user dot's POSITION steps in bucketed
    // travel direction. Decouples visual orientation from the train-on-
    // tracks motion model.
    final phoneFpHeading =
        _normalize(sumHeadingDeg - currentArPose.heading);

    if (lastFp == null || lastAr == null) {
      _lastFpPosition = Offset(referenceFp.x, referenceFp.y);
      _lastArPose = currentArPose;
      return referenceFp.copyWith(
        heading: phoneFpHeading,
        timestamp: currentArPose.timestamp,
        confidence: currentArPose.confidence,
      );
    }

    // AR-world delta in math plane (East, North).
    final curEast = currentArPose.worldX ?? currentArPose.x;
    final curSouth = currentArPose.worldZ ?? -currentArPose.y;
    final lastEast = lastAr.worldX ?? lastAr.x;
    final lastSouth = lastAr.worldZ ?? -lastAr.y;
    final deltaEast = curEast - lastEast;
    final deltaNorth = -(curSouth - lastSouth);
    final stepMeters =
        math.sqrt(deltaEast * deltaEast + deltaNorth * deltaNorth);

    // Below the step gate the walk vector is just sensor noise. Hold the
    // FP position steady but advance the AR anchor and the phone heading
    // so the next non-noise step measures from the most recent AR sample
    // — and the map keeps rotating as the user turns in place.
    if (stepMeters < _minStepMeters) {
      _lastArPose = currentArPose;
      return referenceFp.copyWith(
        x: lastFp.dx,
        y: lastFp.dy,
        heading: phoneFpHeading,
        timestamp: currentArPose.timestamp,
        confidence: currentArPose.confidence,
      );
    }

    // AR-plane angle (CCW from East). Same convention ArPoseTransformer
    // uses for its inverse rotation.
    final arWalkAngleDeg =
        math.atan2(deltaNorth, deltaEast) * 180.0 / math.pi;

    // Travel direction in the floorplan compass frame.
    //   fpAngle = sumHeadingDeg - arAngle
    final fpAngleDeg = _normalize(sumHeadingDeg - arWalkAngleDeg);

    final bucketedDeg =
        bucketCount == 8 ? _bucket8(fpAngleDeg) : _bucket4(fpAngleDeg);

    final bucketedRad = bucketedDeg * math.pi / 180.0;
    final unitX = math.cos(bucketedRad);
    // FP image plane Y is South-positive, which matches sin() for our
    // East=0, South=90° convention.
    final unitY = math.sin(bucketedRad);

    final stepPx = stepMeters / metersPerPixel;
    var candidateFp = Offset(
      lastFp.dx + unitX * stepPx,
      lastFp.dy + unitY * stepPx,
    );

    if (segments.isNotEmpty) {
      final snapThresholdPx = 2.0 / metersPerPixel;
      candidateFp = snapToRouteNetwork(
        candidateFp,
        segments,
        thresholdPx: snapThresholdPx,
      );
    }

    _lastFpPosition = candidateFp;
    _lastArPose = currentArPose;

    return referenceFp.copyWith(
      x: candidateFp.dx,
      y: candidateFp.dy,
      heading: phoneFpHeading,
      timestamp: currentArPose.timestamp,
      confidence: currentArPose.confidence,
    );
  }

  static double _bucket4(double fpDeg) {
    if (fpDeg >= 315.0 || fpDeg < 45.0) return 0.0; // East
    if (fpDeg < 135.0) return 90.0; // South
    if (fpDeg < 225.0) return 180.0; // West
    return 270.0; // North
  }

  static double _bucket8(double fpDeg) {
    final index = ((fpDeg + 22.5) / 45.0).floor() % 8;
    return (index * 45).toDouble();
  }

  static double _normalize(double deg) {
    var n = deg % 360.0;
    if (n < 0) n += 360.0;
    return n;
  }
}
