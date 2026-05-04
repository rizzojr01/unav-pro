import '../../domain/entities/route_entity.dart';
import 'multi_floor_navigation_step_model.dart';

// Indoor floorplans: 1 px is typically 0.005–0.5 m.
// If the value exceeds 1.0 the backend sent feet/pixel — convert to meters.
double? _normalizeToMetersPerPixel(double? raw) {
  if (raw == null) return null;
  if (raw > 1.0) return raw * 0.3048; // feet → meters
  return raw;
}

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.entityId,
    required super.multiFloorSteps,
    super.metersPerPixel,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final multiSteps =
        (json['multifloor_navigation_steps'] as List<dynamic>?)
            ?.map(
              (e) => MultiFloorNavigationStepModel.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList() ??
        [];

    return RouteModel(
      entityId:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      multiFloorSteps: multiSteps,
      metersPerPixel: _normalizeToMetersPerPixel(json['meters_per_pixel']?.toDouble()),
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
    );
  }
}
