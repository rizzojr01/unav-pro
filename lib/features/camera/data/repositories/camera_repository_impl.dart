import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/camera_local_datasource.dart';
import '../datasources/camera_remote_datasource.dart';
import '../models/photo_model.dart';

class CameraRepositoryImpl implements CameraRepository {
  final CameraLocalDataSource localDataSource;
  final CameraRemoteDataSource remoteDataSource;

  CameraRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, PhotoEntity>> capturePhoto() async {
    try {
      final photo = await localDataSource.capturePhoto();
      return Right(photo);
    } on PermissionException catch (e) {
      return Left(PermissionFailure(e.message));
    } on AppException catch (e) {
      return Left(CameraFailure(e.message));
    } catch (e) {
      return Left(CameraFailure('Failed to capture photo: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> uploadPhoto(PhotoEntity photo) async {
    try {
      final photoModel = PhotoModel.fromEntity(photo);
      final result = await remoteDataSource.uploadPhoto(photoModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to upload photo: $e'));
    }
  }
}
