import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo_entity.dart';
import '../repositories/camera_repository.dart';

/// Use case for uploading a photo to the backend
class UploadPhotoUseCase implements UseCase<bool, PhotoEntity> {
  final CameraRepository repository;

  UploadPhotoUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(PhotoEntity params) {
    return repository.uploadPhoto(params);
  }
}
