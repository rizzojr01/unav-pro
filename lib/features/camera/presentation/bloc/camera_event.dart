import 'package:equatable/equatable.dart';

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

  const CapturePhotoEvent({this.filePath, this.floor});

  @override
  List<Object?> get props => [filePath, floor];
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
