import 'package:equatable/equatable.dart';
import 'package:smart_sense/features/ar_navigation/domain/entities/ar_pose.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class InitializeCameraEvent extends CameraEvent {
  const InitializeCameraEvent();
}

class CapturePhotoEvent extends CameraEvent {
  final String? filePath;
  final String? floor;
  final double? heading;
  final ArPose? capturedArPose;

  const CapturePhotoEvent({
    this.filePath,
    this.floor,
    this.heading,
    this.capturedArPose,
  });

  @override
  List<Object?> get props => [filePath, floor, heading, capturedArPose];
}

class UploadPhotoEvent extends CameraEvent {
  const UploadPhotoEvent();
}

class CaptureWithManualCoordinatesEvent extends CameraEvent {
  final double x;
  final double y;

  const CaptureWithManualCoordinatesEvent({required this.x, required this.y});

  @override
  List<Object?> get props => [x, y];
}
