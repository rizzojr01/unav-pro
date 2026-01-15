import '../../../../core/base/base_entity.dart';

/// Entity representing the user's position on the floor plan
class UserPositionEntity extends BaseEntity {
  final double x;
  final double y;
  final double angle;

  const UserPositionEntity({
    required this.x,
    required this.y,
    required this.angle,
  });

  @override
  String? get id => '${x}_${y}_$angle';

  @override
  List<Object?> get props => [x, y, angle];
}
