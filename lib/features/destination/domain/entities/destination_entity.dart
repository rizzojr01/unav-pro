import '../../../../core/base/base_entity.dart';

class DestinationEntity extends BaseEntity {
  final String destinationId;
  final String name;
  final double x;
  final double y;
  final String? floor;
  final String? address;

  const DestinationEntity({
    required this.destinationId,
    required this.name,
    required this.x,
    required this.y,
    this.floor,
    this.address,
  });

  @override
  String? get id => destinationId;

  @override
  List<Object?> get props => [destinationId, name, x, y, floor, address];
}
