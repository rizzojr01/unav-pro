import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo_entity.dart';

abstract class CameraRepository {
  Future<Either<Failure, PhotoEntity>> capturePhoto();
  Future<Either<Failure, bool>> uploadPhoto(PhotoEntity photo);
}
