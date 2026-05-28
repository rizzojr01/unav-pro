import '../../../../core/base/base_state.dart';
import '../../../ar_navigation/domain/entities/ar_pose.dart';
import '../../domain/entities/photo_entity.dart';

abstract class CameraState extends BaseState {
  const CameraState();
}

class CameraInitial extends CameraState {
  const CameraInitial();
}

class CameraReady extends CameraState {
  const CameraReady();
}

class CameraCapturing extends CameraState {
  const CameraCapturing();
}

class CameraPhotoCaptured extends CameraState {
  final PhotoEntity photo;
  final String? floor;
  final double? heading;
  final ArPose? capturedArPose;

  const CameraPhotoCaptured(
    this.photo, {
    this.floor,
    this.heading,
    this.capturedArPose,
  });

  @override
  List<Object?> get props => [photo, floor, heading, capturedArPose];
}

class CameraUploading extends CameraState {
  final PhotoEntity photo;

  const CameraUploading(this.photo);

  @override
  List<Object?> get props => [photo];
}

class CameraPhotoUploaded extends CameraState {
  final PhotoEntity photo;

  const CameraPhotoUploaded(this.photo);

  @override
  List<Object?> get props => [photo];
}

class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}
