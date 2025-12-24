import '../../domain/entities/destination_entity.dart';

class DestinationModel extends DestinationEntity {
  const DestinationModel({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    super.address,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  factory DestinationModel.fromEntity(DestinationEntity entity) {
    return DestinationModel(
      id: entity.id,
      name: entity.name,
      latitude: entity.latitude,
      longitude: entity.longitude,
      address: entity.address,
    );
  }
}
