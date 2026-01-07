import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/base/usecase.dart';
import 'package:smart_sense/core/error/failures.dart';
import 'package:smart_sense/features/auth/domain/entities/auth_token_entity.dart';
import 'package:smart_sense/features/auth/domain/repositories/auth_repository.dart';

class SignupParams {
  final String email;
  final String nickname;
  final String password;

  SignupParams({
    required this.email,
    required this.nickname,
    required this.password,
  });
}

class SignupUseCase extends UseCase<AuthTokenEntity, SignupParams> {
  final AuthRepository repository;

  SignupUseCase(this.repository);

  @override
  Future<Either<Failure, AuthTokenEntity>> call(SignupParams params) async {
    return await repository.signup(
      email: params.email,
      nickname: params.nickname,
      password: params.password,
    );
  }
}
