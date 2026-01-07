import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/base/usecase.dart';
import 'package:smart_sense/core/error/failures.dart';
import 'package:smart_sense/features/auth/domain/entities/auth_token_entity.dart';
import 'package:smart_sense/features/auth/domain/repositories/auth_repository.dart';

class LoginParams {
  final String email;
  final String password;

  LoginParams({required this.email, required this.password});
}

class LoginUseCase extends UseCase<AuthTokenEntity, LoginParams> {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  @override
  Future<Either<Failure, AuthTokenEntity>> call(LoginParams params) async {
    return await repository.login(
      email: params.email,
      password: params.password,
    );
  }
}
