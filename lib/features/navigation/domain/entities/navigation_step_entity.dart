import '../../../../core/base/base_entity.dart';
import 'location_entity.dart';

class NavigationStepEntity extends BaseEntity {
  final LocationEntity from;
  final LocationEntity to;
  final double distanceMeters;
  final int distanceFeet;
  final double orientationDegrees;
  final String compassDirection;

  const NavigationStepEntity({
    required this.from,
    required this.to,
    required this.distanceMeters,
    required this.distanceFeet,
    required this.orientationDegrees,
    required this.compassDirection,
  });

  @override
  String? get id => '${from.id}_${to.id}';

  @override
  List<Object?> get props => [
    from,
    to,
    distanceMeters,
    distanceFeet,
    orientationDegrees,
    compassDirection,
  ];
}
