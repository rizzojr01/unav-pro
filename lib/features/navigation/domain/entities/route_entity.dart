import '../../../../core/base/base_entity.dart';
import 'navigation_step_entity.dart';
import 'multi_floor_navigation_step_entity.dart';
import 'location_entity.dart';

class RouteEntity extends BaseEntity {
  final String entityId;
  final List<MultiFloorNavigationStepEntity> multiFloorSteps;

  const RouteEntity({required this.entityId, required this.multiFloorSteps});

  /// Flat list of all steps across all floors
  List<NavigationStepEntity> get steps =>
      multiFloorSteps.expand((floor) => floor.steps).toList();

  /// Start location of the route
  LocationEntity get origin =>
      steps.isEmpty ? const LocationEntity(x: 0, y: 0) : steps.first.from;

  /// End location of the route
  LocationEntity get destination =>
      steps.isEmpty ? const LocationEntity(x: 0, y: 0) : steps.last.to;

  @override
  String? get id => entityId;

  @override
  List<Object?> get props => [entityId, multiFloorSteps];
}
