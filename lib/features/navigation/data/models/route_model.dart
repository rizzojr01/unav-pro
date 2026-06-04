import 'dart:math' as math;
import 'dart:ui';

import '../../domain/entities/route_entity.dart';
import 'multi_floor_navigation_step_model.dart';

// Indoor floorplans: 1 px is typically 0.005-0.5 m.
// If the value exceeds 1.0 the backend likely sent feet/pixel; convert to m/px.
double? _normalizeToMetersPerPixel(double? raw) {
  if (raw == null) return null;
  // Standard floorplans are usually 0.05 - 0.2 mpp.
  // If raw > 1.0, it's almost certainly feet per pixel (e.g. 5.0 fpp).
  if (raw > 1.0) return raw * 0.3048; // feet to meters
  return raw;
}

double? _deriveMetersPerPixelFromSteps(
  List<MultiFloorNavigationStepModel> multiSteps,
) {
  final samples = <double>[];
  for (final floorStep in multiSteps) {
    for (final step in floorStep.steps) {
      final dx = step.to.x - step.from.x;
      final dy = step.to.y - step.from.y;
      final pixelDistance = math.sqrt(dx * dx + dy * dy);
      if (pixelDistance <= 1e-6 || step.distanceMeters <= 0) continue;

      final metersPerPixel = step.distanceMeters / pixelDistance;
      if (metersPerPixel.isFinite && metersPerPixel > 0) {
        samples.add(metersPerPixel);
      }
    }
  }

  if (samples.isEmpty) return null;
  samples.sort();
  final middle = samples.length ~/ 2;
  if (samples.length.isOdd) return samples[middle];
  return (samples[middle - 1] + samples[middle]) / 2.0;
}

List<(Offset, Offset)> _parseRouteNetworkSegments(dynamic raw) {
  if (raw is! List) return const [];
  final result = <(Offset, Offset)>[];
  for (final seg in raw) {
    if (seg is! Map) continue;
    final from = seg['from'];
    final to = seg['to'];
    final fromOffset = _readOffset(from);
    final toOffset = _readOffset(to);
    if (fromOffset == null || toOffset == null) continue;
    result.add((fromOffset, toOffset));
  }
  return result;
}

Offset? _readOffset(dynamic raw) {
  if (raw is List && raw.length >= 2 && raw[0] is num && raw[1] is num) {
    return Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
  }
  if (raw is Map && raw['x'] is num && raw['y'] is num) {
    return Offset((raw['x'] as num).toDouble(), (raw['y'] as num).toDouble());
  }
  return null;
}

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.entityId,
    required super.multiFloorSteps,
    super.metersPerPixel,
    super.routeNetworkSegments,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final multiSteps = (json['multifloor_navigation_steps'] as List<dynamic>?)
            ?.map(
              (e) => MultiFloorNavigationStepModel.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList() ??
        [];

    return RouteModel(
      entityId: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      multiFloorSteps: multiSteps,
      metersPerPixel: _deriveMetersPerPixelFromSteps(multiSteps) ??
          _normalizeToMetersPerPixel(json['meters_per_pixel']?.toDouble()),
      routeNetworkSegments: _parseRouteNetworkSegments(json['route_segments']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': entityId,
      'multifloor_navigation_steps': multiFloorSteps
          .map((e) => MultiFloorNavigationStepModel.fromEntity(e).toJson())
          .toList(),
      'meters_per_pixel': metersPerPixel,
    };
  }

  factory RouteModel.fromEntity(RouteEntity entity) {
    return RouteModel(
      entityId: entity.entityId,
      multiFloorSteps: entity.multiFloorSteps,
      metersPerPixel: entity.metersPerPixel,
      routeNetworkSegments: entity.routeNetworkSegments,
    );
  }
}
