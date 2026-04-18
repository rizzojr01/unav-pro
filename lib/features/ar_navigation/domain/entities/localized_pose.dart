import 'package:equatable/equatable.dart';
import 'package:smart_sense/features/navigation/domain/entities/location_entity.dart';

class LocalizedPose extends Equatable {
  final String floorKey;
  final double x;
  final double y;
  final double z;
  final double heading;
  final double confidence;
  final DateTime timestamp;

  const LocalizedPose({
    required this.floorKey,
    required this.x,
    required this.y,
    required this.z,
    required this.heading,
    required this.confidence,
    required this.timestamp,
  });

  LocationEntity toLocationEntity() {
    return LocationEntity(x: x, y: y, floor: floorKey, timestamp: timestamp);
  }

  @override
  List<Object?> get props => [
    floorKey,
    x,
    y,
    z,
    heading,
    confidence,
    timestamp,
  ];
}
