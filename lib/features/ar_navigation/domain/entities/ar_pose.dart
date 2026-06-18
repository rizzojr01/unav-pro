import 'package:equatable/equatable.dart';

class ArPose extends Equatable {
  final double x;
  final double y;
  final double z;
  final double heading;
  final double confidence;
  final DateTime timestamp;
  // Raw ARKit world-space coordinates (metres, worldAlignment = .gravity).
  // +Y = Up; +X/+Z are session-relative — fixed by the device's orientation
  // at session start, NOT compass-aligned.
  final double? worldX;
  final double? worldY;
  final double? worldZ;

  const ArPose({
    required this.x,
    required this.y,
    required this.z,
    required this.heading,
    required this.confidence,
    required this.timestamp,
    this.worldX,
    this.worldY,
    this.worldZ,
  });

  ArPose copyWith({
    double? x,
    double? y,
    double? z,
    double? heading,
    double? confidence,
    DateTime? timestamp,
    double? worldX,
    double? worldY,
    double? worldZ,
  }) {
    return ArPose(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      heading: heading ?? this.heading,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      worldX: worldX ?? this.worldX,
      worldY: worldY ?? this.worldY,
      worldZ: worldZ ?? this.worldZ,
    );
  }

  @override
  List<Object?> get props => [x, y, z, heading, confidence, timestamp, worldX, worldY, worldZ];
}
