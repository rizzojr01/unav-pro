import '../../../../core/base/base_state.dart';
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

  const CameraPhotoCaptured(this.photo);

  @override
  List<Object?> get props => [photo];
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
