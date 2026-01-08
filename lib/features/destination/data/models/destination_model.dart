import '../../domain/entities/destination_entity.dart';

class DestinationModel extends DestinationEntity {
  const DestinationModel({
    required super.entityId,
    required super.name,
    required super.x,
    required super.y,
    super.address,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      entityId: json['id'] as String,
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id!, 'name': name, 'x': x, 'y': y, 'address': address};
  }

  factory DestinationModel.fromEntity(DestinationEntity entity) {
    return DestinationModel(
      entityId: entity.id!,
      name: entity.name,
      x: entity.x,
      y: entity.y,
      address: entity.address,
    );
  }
}
