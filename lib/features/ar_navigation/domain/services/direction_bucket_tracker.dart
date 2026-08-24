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
  // A single frame-to-frame jump above this is an ARKit relocalization snap,
  // not walking — re-anchor without moving the dot.
  static const double _maxStepMeters = 3.0;

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
    bool snapToRoute = true,
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

    // Below the step gate the walk vector might be sensor noise OR just a
    // small fraction of a normal walking step (30 fps × 1 m/s ≈ 3 cm per
    // frame). Keep `_lastArPose` pointing at the last *committed* sample
    // so subsequent frames accumulate against it — otherwise advancing
    // the anchor every frame would forever reset the accumulator and
    // the user dot would never move.
    if (stepMeters < _minStepMeters) {
      return referenceFp.copyWith(
        x: lastFp.dx,
        y: lastFp.dy,
        heading: phoneFpHeading,
        timestamp: currentArPose.timestamp,
        confidence: currentArPose.confidence,
      );
    }
    if (stepMeters > _maxStepMeters) {
      // ARKit relocalized with a position snap. Consume the jump so it
      // doesn't turn into a phantom multi-meter stride along one bucket.
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
    final fpAngleRad = fpAngleDeg * math.pi / 180.0;
    // FP image plane Y is South-positive, which matches sin() for our
    // East=0, South=90° convention.
    final rawWalkUnit = Offset(math.cos(fpAngleRad), math.sin(fpAngleRad));

    final snapThresholdPx = 2.0 / metersPerPixel;
    final stepPx = stepMeters / metersPerPixel;

    // Free-roam: user opted out of the rails — dead-reckon in the raw walk
    // direction, no track selection, no snapping. The dot follows the user
    // anywhere, including off the walkable area (and, with yaw drift,
    // through walls — that is the trade the toggle makes).
    if (!snapToRoute) {
      final freeFp = Offset(
        lastFp.dx + rawWalkUnit.dx * stepPx,
        lastFp.dy + rawWalkUnit.dy * stepPx,
      );
      _lastFpPosition = freeFp;
      _lastArPose = currentArPose;
      return referenceFp.copyWith(
        x: freeFp.dx,
        y: freeFp.dy,
        heading: phoneFpHeading,
        timestamp: currentArPose.timestamp,
        confidence: currentArPose.confidence,
      );
    }

    // The corridors themselves are the "tracks": step along the nearby
    // corridor direction that best matches the raw walk vector AND actually
    // advances the dot. Compass buckets alone pin the dot at corners — after
    // a turn, yaw drift can land the walk in a bucket perpendicular to the
    // new corridor (or along the old, ended one), and the snap then projects
    // every step back onto the corner vertex forever.
    final trackDirs =
        _trackDirections(lastFp, segments, snapThresholdPx, rawWalkUnit);

    Offset candidateFp = lastFp;
    var progressed = false;
    for (final dir in trackDirs) {
      final tryFp = Offset(
        lastFp.dx + dir.dx * stepPx,
        lastFp.dy + dir.dy * stepPx,
      );
      final snapped =
          snapToRouteNetwork(tryFp, segments, thresholdPx: snapThresholdPx);
      if ((snapped - lastFp).distance >= 0.25 * stepPx) {
        candidateFp = snapped;
        progressed = true;
        break;
      }
    }

    if (!progressed && trackDirs.isEmpty) {
      // Off the corridor graph (or no graph at all): original compass-bucket
      // behavior.
      final unit = _compassBucketUnit(fpAngleDeg);
      candidateFp = Offset(
        lastFp.dx + unit.dx * stepPx,
        lastFp.dy + unit.dy * stepPx,
      );
      if (segments.isNotEmpty) {
        candidateFp = snapToRouteNetwork(
          candidateFp,
          segments,
          thresholdPx: snapThresholdPx,
        );
      }
    }
    // ponytail: if no track direction progresses (dead end / walking into a
    // wall), the dot deliberately stays put — that is the honest reading.

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

  /// Signed unit directions of corridor segments within [thresholdPx] of
  /// [point], oriented toward [walkUnit] and sorted best-aligned first.
  /// Perpendicular/backward directions (dot ≤ 0.05) are dropped. Empty when
  /// no segment is nearby — caller falls back to compass bucketing.
  static List<Offset> _trackDirections(
    Offset point,
    List<(Offset, Offset)> segments,
    double thresholdPx,
    Offset walkUnit,
  ) {
    final thresholdSq = thresholdPx * thresholdPx;
    final scored = <(double, Offset)>[];
    for (final (a, b) in segments) {
      final ab = b - a;
      final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
      if (abLenSq <= 1e-6) continue;
      final ap = point - a;
      final t = ((ap.dx * ab.dx) + (ap.dy * ab.dy)) / abLenSq;
      final proj = a + ab * t.clamp(0.0, 1.0);
      final dx = point.dx - proj.dx;
      final dy = point.dy - proj.dy;
      if (dx * dx + dy * dy > thresholdSq) continue;
      final abLen = math.sqrt(abLenSq);
      var dir = Offset(ab.dx / abLen, ab.dy / abLen);
      var dot = (walkUnit.dx * dir.dx) + (walkUnit.dy * dir.dy);
      // Orient toward the walk: walking a segment "backwards" is on-track.
      if (dot < 0) {
        dir = Offset(-dir.dx, -dir.dy);
        dot = -dot;
      }
      if (dot <= 0.05) continue;
      scored.add((dot, dir));
    }
    scored.sort((x, y) => y.$1.compareTo(x.$1));
    return [for (final s in scored) s.$2];
  }

  Offset _compassBucketUnit(double fpAngleDeg) {
    final bucketedDeg =
        bucketCount == 8 ? _bucket8(fpAngleDeg) : _bucket4(fpAngleDeg);
    final bucketedRad = bucketedDeg * math.pi / 180.0;
    return Offset(math.cos(bucketedRad), math.sin(bucketedRad));
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
