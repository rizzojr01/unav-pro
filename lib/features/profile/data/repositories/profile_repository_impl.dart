import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/error/failures.dart';
import 'package:smart_sense/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:smart_sense/features/profile/domain/entities/user_entity.dart';
import 'package:smart_sense/features/profile/domain/repositories/profile_repository.dart';
import 'package:smart_sense/features/profile/data/datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> getMe() async {
    try {
      final token = authLocalDataSource.getToken();
      if (token == null) {
        return const Left<Failure, UserEntity>(
          CacheFailure('Not authenticated'),
        );
      }
      final user = await remoteDataSource.getMe(token);
      await authLocalDataSource.saveUser(user);
      return Right<Failure, UserEntity>(user);
    } catch (e) {
      return Left<Failure, UserEntity>(ServerFailure(e.toString()));
    }
  }
}
