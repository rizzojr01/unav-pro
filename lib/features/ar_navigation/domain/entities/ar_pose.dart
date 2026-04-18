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

  @override
  List<Object?> get props => [x, y, z, heading, confidence, timestamp];
}
