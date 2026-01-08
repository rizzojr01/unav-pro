import '../../../../core/base/base_entity.dart';

class DestinationEntity extends BaseEntity {
  final String entityId;
  final String name;
  final double x;
  final double y;
  final String? address;

  const DestinationEntity({
    required this.entityId,
    required this.name,
    required this.x,
    required this.y,
    this.address,
  });

  @override
  String? get id => entityId;

  @override
  List<Object?> get props => [entityId, name, x, y, address];
}
