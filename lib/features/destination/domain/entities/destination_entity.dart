import '../../../../core/base/base_entity.dart';

class DestinationEntity extends BaseEntity {
  final String entityId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  const DestinationEntity({
    required this.entityId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  String? get id => entityId;

  @override
  List<Object?> get props => [entityId, name, latitude, longitude, address];
}
