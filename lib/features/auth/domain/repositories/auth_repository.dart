import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/error/failures.dart';
import 'package:smart_sense/features/auth/domain/entities/auth_token_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthTokenEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthTokenEntity>> signup({
    required String email,
    required String nickname,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, bool>> isAuthenticated();
}
