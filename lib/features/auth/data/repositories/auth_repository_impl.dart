import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/error/failures.dart';
import 'package:smart_sense/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:smart_sense/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:smart_sense/features/profile/data/models/user_model.dart';
import 'package:smart_sense/features/auth/domain/entities/auth_token_entity.dart';
import 'package:smart_sense/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, AuthTokenEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await remoteDataSource.login(
        email: email,
        password: password,
      );
      await localDataSource.saveToken(response.accessToken);
      await localDataSource.saveUser(response.user as UserModel);
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokenEntity>> signup({
    required String email,
    required String nickname,
    required String password,
  }) async {
    try {
      final response = await remoteDataSource.signup(
        email: email,
        nickname: nickname,
        password: password,
      );
      await localDataSource.saveToken(response.accessToken);
      await localDataSource.saveUser(response.user as UserModel);
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await localDataSource.clearAll();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isAuthenticated() async {
    try {
      final token = localDataSource.getToken();
      return Right(token != null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
