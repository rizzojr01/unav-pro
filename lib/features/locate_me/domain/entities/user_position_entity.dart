import '../../../../core/base/base_entity.dart';

/// Entity representing the user's position on the floor plan
class UserPositionEntity extends BaseEntity {
  final double x;
  final double y;
  final double angle;
  final String? floor;

  const UserPositionEntity({
    required this.x,
    required this.y,
    required this.angle,
    this.floor,
  });

  UserPositionEntity copyWith({
    double? x,
    double? y,
    double? angle,
    String? floor,
  }) {
    return UserPositionEntity(
      x: x ?? this.x,
      y: y ?? this.y,
      angle: angle ?? this.angle,
      floor: floor ?? this.floor,
    );
  }

  @override
  String? get id => '${x}_${y}_$angle';

  @override
  List<Object?> get props => [x, y, angle, floor];
}
