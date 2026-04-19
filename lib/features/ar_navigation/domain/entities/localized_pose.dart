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
    return LocationEntity(
      x: x,
      y: y,
      floor: floorKey,
      timestamp: timestamp,
      ang: heading,
    );
  }

  LocalizedPose copyWith({
    String? floorKey,
    double? x,
    double? y,
    double? z,
    double? heading,
    double? confidence,
    DateTime? timestamp,
  }) {
    return LocalizedPose(
      floorKey: floorKey ?? this.floorKey,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      heading: heading ?? this.heading,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
    );
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
