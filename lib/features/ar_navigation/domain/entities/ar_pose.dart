import 'package:equatable/equatable.dart';

class ArPose extends Equatable {
  final double x;
  final double y;
  final double z;
  final double heading;
  final double confidence;
  final DateTime timestamp;

  const ArPose({
    required this.x,
    required this.y,
    required this.z,
    required this.heading,
    required this.confidence,
    required this.timestamp,
  });

  ArPose copyWith({
    double? x,
    double? y,
    double? z,
    double? heading,
    double? confidence,
    DateTime? timestamp,
  }) {
    return ArPose(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      heading: heading ?? this.heading,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [x, y, z, heading, confidence, timestamp];
}
