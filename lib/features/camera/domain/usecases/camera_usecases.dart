import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo_entity.dart';
import '../repositories/camera_repository.dart';

class CapturePhotoUseCase implements UseCase<PhotoEntity, NoParams> {
  final CameraRepository repository;

  CapturePhotoUseCase(this.repository);

  @override
  Future<Either<Failure, PhotoEntity>> call(NoParams params) {
    return repository.capturePhoto();
  }
}

class UploadPhotoUseCase implements UseCase<bool, PhotoEntity> {
  final CameraRepository repository;

  UploadPhotoUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(PhotoEntity params) {
    return repository.uploadPhoto(params);
  }
}
