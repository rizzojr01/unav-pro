import '../../../../core/base/base_entity.dart';
import 'navigation_step_entity.dart';

class MultiFloorNavigationStepEntity extends BaseEntity {
  final String floor;
  final List<NavigationStepEntity> steps;

  const MultiFloorNavigationStepEntity({
    required this.floor,
    required this.steps,
  });

  @override
  String? get id => floor;

  @override
  List<Object?> get props => [floor, steps];
}
