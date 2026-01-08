import '../../domain/entities/location_entity.dart';

class LocationModel extends LocationEntity {
  const LocationModel({required super.x, required super.y, super.timestamp});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'timestamp': timestamp?.toIso8601String()};
  }

  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(x: entity.x, y: entity.y, timestamp: entity.timestamp);
  }
}
