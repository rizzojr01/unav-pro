import 'package:dartz/dartz.dart';

import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_position_entity.dart';
import '../entities/localization_request_entity.dart';
import '../repositories/locate_me_repository.dart';

class LocalizeUserUseCase
    implements UseCase<UserPositionEntity, LocalizationRequestEntity> {
  final LocateMeRepository repository;

  LocalizeUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserPositionEntity>> call(
    LocalizationRequestEntity params,
  ) {
    return repository.localizeUser(params);
  }
}
