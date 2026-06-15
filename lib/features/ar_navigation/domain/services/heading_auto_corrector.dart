import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Auto-tunes the AR heading offset by comparing the user's observed
/// floorplan walk direction against the nearest navigable route segment
/// direction.
///
/// Algorithm (per Appendix A.3.1 of `path_docs.md`):
///   1. Buffer recent (timestamp, unsnapped floorplan pose, AR world pos).
///   2. When the user has walked ≥ [minimumWalkMeters] within
///      [bufferWindow]:
///        a. Compute observed FP walk direction (oldest → newest).
///        b. Pick the route segment nearest the latest snapped pose.
///        c. Verify the walk is roughly parallel to that segment
///           (`|cos θ| ≥ [parallelDotThreshold]`) — skips turns/junctions.
///        d. Compute signed yaw error `segDir − observedFpDir`.
///        e. If `|yawError| ≤ [maxCorrectionDeg]`, fold it into the
///           current offset with an EMA (`α = [emaAlpha]`).
///        f. Clamp the per-call delta to [maxPerCallDeltaDeg] to avoid
///           visible AR jitter.
///   3. Return the proposed new offset, or null when no update is safe.
///
/// Pure logic. No Flutter dependencies beyond `Offset`. Safe to unit test.
class HeadingAutoCorrector {
  HeadingAutoCorrector({
    this.bufferWindow = const Duration(seconds: 3),
    this.minimumWalkMeters = 1.5,
    this.parallelDotThreshold = 0.9,
    this.maxCorrectionDeg = 8.0,
    this.emaAlpha = 0.85,
    this.maxPerCallDeltaDeg = 0.5,
  });

  final Duration bufferWindow;
  final double minimumWalkMeters;
  final double parallelDotThreshold;
  final double maxCorrectionDeg;
  final double emaAlpha;
  final double maxPerCallDeltaDeg;

  final List<_Sample> _samples = <_Sample>[];

  void reset() => _samples.clear();

  /// Observes one frame and returns a new heading offset if a correction is
  /// warranted. Returns null otherwise (caller keeps the current offset).
  ///
  /// All inputs are required to be in their respective canonical frames:
  /// - [unsnappedFpPose]: the pose produced by `ArPoseTransformer.transform`
  ///   **before** any route snapping. Floorplan pixel coordinates.
  /// - [arWorldPos]: ARKit world-space position (East/Up/South). Only the
  ///   horizontal component (worldX, worldZ) is used.
  /// - [snappedFpPose]: the same pose **after** snap-to-route. Used only to
  ///   pick the nearest segment.
  /// - [segments]: navmesh as a list of (from, to) endpoints in floorplan
  ///   pixel coordinates.
  /// - [metersPerPixel]: floorplan scale, used to translate the FP walk
  ///   distance into meters for the gate check.
  /// - [currentOffsetDeg]: the offset currently in effect.
  /// - [timestamp]: monotonic sample time.
  double? observe({
    required Offset unsnappedFpPose,
    required Offset arWorldPos,
    required Offset snappedFpPose,
    required List<(Offset, Offset)> segments,
    required double metersPerPixel,
    required double currentOffsetDeg,
    required DateTime timestamp,
  }) {
    if (segments.isEmpty || metersPerPixel <= 0) return null;

    _samples.add(_Sample(
      t: timestamp,
      fp: unsnappedFpPose,
      ar: arWorldPos,
    ));
    final cutoff = timestamp.subtract(bufferWindow);
    while (_samples.isNotEmpty && _samples.first.t.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
    if (_samples.length < 2) return null;

    final first = _samples.first;
    final last = _samples.last;

    final arDx = last.ar.dx - first.ar.dx;
    final arDy = last.ar.dy - first.ar.dy;
    final arWalkMeters = math.sqrt(arDx * arDx + arDy * arDy);
    if (arWalkMeters < minimumWalkMeters) return null;

    final fpDx = last.fp.dx - first.fp.dx;
    final fpDy = last.fp.dy - first.fp.dy;
    final fpWalkPx = math.sqrt(fpDx * fpDx + fpDy * fpDy);
    final fpWalkMeters = fpWalkPx * metersPerPixel;
    if (fpWalkMeters < minimumWalkMeters * 0.5) return null;

    final segment = _nearestSegment(snappedFpPose, segments);
    if (segment == null) return null;

    final segDx = segment.$2.dx - segment.$1.dx;
    final segDy = segment.$2.dy - segment.$1.dy;
    final segLen = math.sqrt(segDx * segDx + segDy * segDy);
    if (segLen <= 1e-6) return null;

    final dot =
        ((fpDx * segDx) + (fpDy * segDy)) / (fpWalkPx * segLen);
    if (dot.abs() < parallelDotThreshold) return null;

    // Math-plane direction of the segment (and the observed walk). Both use
    // the same image-pixel basis, so y-flip is unnecessary for the *difference*.
    final segDirDeg = _atan2Deg(segDy, segDx);
    final obsDirDeg = _atan2Deg(fpDy, fpDx);

    // If the user walked the segment backwards, flip the reference 180°
    // before computing the error so we never inject a half-turn.
    final orientedSegDirDeg =
        dot >= 0 ? segDirDeg : _normalizeDeg(segDirDeg + 180.0);

    final yawErrorDeg = _signedDeltaDeg(obsDirDeg, orientedSegDirDeg);
    if (yawErrorDeg.abs() > maxCorrectionDeg) return null;

    // EMA: nudge current offset toward (current + yawError).
    final blended = currentOffsetDeg + (1.0 - emaAlpha) * yawErrorDeg;
    final delta = blended - currentOffsetDeg;
    final clampedDelta =
        delta.clamp(-maxPerCallDeltaDeg, maxPerCallDeltaDeg);
    final proposed = currentOffsetDeg + clampedDelta;

    if ((proposed - currentOffsetDeg).abs() < 1e-3) return null;
    return proposed;
  }

  (Offset, Offset)? _nearestSegment(
    Offset point,
    List<(Offset, Offset)> segments,
  ) {
    double bestDistSq = double.infinity;
    (Offset, Offset)? best;
    for (final seg in segments) {
      final a = seg.$1;
      final b = seg.$2;
      final abDx = b.dx - a.dx;
      final abDy = b.dy - a.dy;
      final abLenSq = abDx * abDx + abDy * abDy;
      if (abLenSq <= 1e-6) continue;
      final apDx = point.dx - a.dx;
      final apDy = point.dy - a.dy;
      final t = ((apDx * abDx) + (apDy * abDy)) / abLenSq;
      final clampedT = t.clamp(0.0, 1.0);
      final projDx = a.dx + abDx * clampedT;
      final projDy = a.dy + abDy * clampedT;
      final dx = point.dx - projDx;
      final dy = point.dy - projDy;
      final dSq = dx * dx + dy * dy;
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        best = seg;
      }
    }
    return best;
  }

  static double _atan2Deg(double y, double x) =>
      _normalizeDeg(math.atan2(y, x) * 180.0 / math.pi);

  static double _normalizeDeg(double v) {
    var n = v % 360.0;
    if (n < 0) n += 360.0;
    return n;
  }

  static double _signedDeltaDeg(double from, double to) {
    var d = (to - from + 540.0) % 360.0 - 180.0;
    if (d < -180.0) d += 360.0;
    return d;
  }
}

class _Sample {
  _Sample({required this.t, required this.fp, required this.ar});
  final DateTime t;
  final Offset fp;
  final Offset ar;
}
