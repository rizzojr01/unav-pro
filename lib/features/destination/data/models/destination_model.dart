import '../../domain/entities/destination_entity.dart';

class DestinationModel extends DestinationEntity {
  const DestinationModel({
    required super.destinationId,
    required super.name,
    required super.x,
    required super.y,
    super.address,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    // Support both x/y and latitude/longitude field names
    final xValue = json['x'] ?? json['latitude'] ?? 0;
    final yValue = json['y'] ?? json['longitude'] ?? 0;

    return DestinationModel(
      destinationId: json['id'] as String,
      name: json['name'] as String,
      x: (xValue as num).toDouble(),
      y: (yValue as num).toDouble(),
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id!, 'name': name, 'x': x, 'y': y, 'address': address};
  }

  factory DestinationModel.fromEntity(DestinationEntity entity) {
    return DestinationModel(
      destinationId: entity.id!,
      name: entity.name,
      x: entity.x,
      y: entity.y,
      address: entity.address,
    );
  }

  static List<DestinationModel> fromJsonList(Map<String, dynamic> json) {
    final destinations = json['destinations'] as List<dynamic>;
    return destinations
        .map((e) => DestinationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
