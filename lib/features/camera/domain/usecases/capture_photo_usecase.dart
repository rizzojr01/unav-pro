import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo_entity.dart';
import '../repositories/camera_repository.dart';

/// Use case for capturing a photo
class CapturePhotoUseCase implements UseCase<PhotoEntity, NoParams> {
  final CameraRepository repository;

  CapturePhotoUseCase(this.repository);

  @override
  Future<Either<Failure, PhotoEntity>> call(NoParams params) {
    return repository.capturePhoto();
  }
}
