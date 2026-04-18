import '../../../../core/base/base_entity.dart';

/// Entity representing the user's position on the floor plan
class UserPositionEntity extends BaseEntity {
  final double x;
  final double y;
  final String? floor;

  const UserPositionEntity({required this.x, required this.y, this.floor});

  UserPositionEntity copyWith({double? x, double? y, String? floor}) {
    return UserPositionEntity(
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
    );
  }

  @override
  String? get id => '${x}_$y';

  @override
  List<Object?> get props => [x, y, floor];
}
