import '../../../../core/base/base_entity.dart';

class DestinationEntity extends BaseEntity {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  const DestinationEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  List<Object?> get props => [id, name, latitude, longitude, address];
}
