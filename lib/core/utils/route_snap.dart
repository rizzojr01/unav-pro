import 'dart:ui';

/// Projects [point] onto the nearest segment in [segments].
///
/// Each segment is `(from, to)` in the same coordinate space as [point]
/// (typically floorplan pixel coordinates).
///
/// If [thresholdPx] is provided and the nearest projection lies farther than
/// that distance from [point], the raw [point] is returned instead. This
/// prevents a stray pose from being yanked onto a distant route line.
///
/// Returns [point] unchanged when [segments] is empty.
Offset snapToRouteNetwork(
  Offset point,
  List<(Offset, Offset)> segments, {
  double? thresholdPx,
}) {
  if (segments.isEmpty) return point;

  double bestDistSq = double.infinity;
  Offset best = point;

  for (final (a, b) in segments) {
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq <= 1e-6) continue;

    final ap = point - a;
    final t = ((ap.dx * ab.dx) + (ap.dy * ab.dy)) / abLenSq;
    final proj = a + ab * t.clamp(0.0, 1.0);

    final dx = point.dx - proj.dx;
    final dy = point.dy - proj.dy;
    final dSq = dx * dx + dy * dy;

    if (dSq < bestDistSq) {
      bestDistSq = dSq;
      best = proj;
    }
  }

  if (thresholdPx != null && bestDistSq > thresholdPx * thresholdPx) {
    return point;
  }
  return best;
}
