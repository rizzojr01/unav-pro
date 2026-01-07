import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/base/usecase.dart';
import 'package:smart_sense/core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class GetMeUseCase extends UseCase<UserEntity, NoParams> {
  final ProfileRepository repository;

  GetMeUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) async {
    return await repository.getMe();
  }
}
