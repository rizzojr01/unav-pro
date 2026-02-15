import '../../domain/entities/route_entity.dart';
import 'multi_floor_navigation_step_model.dart';

class RouteModel extends RouteEntity {
  const RouteModel({required super.entityId, required super.multiFloorSteps});

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': entityId,
      'multifloor_navigation_steps': multiFloorSteps
          .map((e) => MultiFloorNavigationStepModel.fromEntity(e).toJson())
          .toList(),
    };
  }

  factory RouteModel.fromEntity(RouteEntity entity) {
    return RouteModel(
      entityId: entity.entityId,
      multiFloorSteps: entity.multiFloorSteps,
    );
  }
}
