import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/camera_local_datasource.dart';
import '../datasources/camera_remote_datasource.dart';

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
      // For now, return a mock photo to bypass hardware/simulator issues
      await Future.delayed(const Duration(seconds: 1));
      return Right(
        PhotoEntity(
          entityId: 'mock-photo-${DateTime.now().millisecondsSinceEpoch}',
          filePath: 'mock_photo_path.jpg',
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left(CameraFailure('Failed to capture photo: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> uploadPhoto(PhotoEntity photo) async {
    try {
      // For now, return success to bypass backend issues
      await Future.delayed(const Duration(seconds: 1));
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure('Failed to upload photo: $e'));
    }
  }
}
