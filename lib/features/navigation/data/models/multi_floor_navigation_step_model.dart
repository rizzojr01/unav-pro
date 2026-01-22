import '../../domain/entities/multi_floor_navigation_step_entity.dart';
import 'navigation_step_model.dart';

class MultiFloorNavigationStepModel extends MultiFloorNavigationStepEntity {
  const MultiFloorNavigationStepModel({
    required super.floor,
    required super.steps,
  });

  factory MultiFloorNavigationStepModel.fromJson(Map<String, dynamic> json) {
    return MultiFloorNavigationStepModel(
      floor: json['floor'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((e) => NavigationStepModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'floor': floor,
      'steps': steps
          .map((e) => NavigationStepModel.fromEntity(e).toJson())
          .toList(),
    };
  }

  factory MultiFloorNavigationStepModel.fromEntity(
    MultiFloorNavigationStepEntity entity,
  ) {
    return MultiFloorNavigationStepModel(
      floor: entity.floor,
      steps: entity.steps,
    );
  }
}
