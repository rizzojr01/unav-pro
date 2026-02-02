import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/localization_history_entity.dart';
import '../repositories/localization_history_repository.dart';

class GetUserLocalizationHistoryUseCase
    implements UseCase<List<LocalizationHistoryEntity>, GetUserHistoryParams> {
  final LocalizationHistoryRepository repository;

  GetUserLocalizationHistoryUseCase({required this.repository});

  @override
  Future<Either<Failure, List<LocalizationHistoryEntity>>> call(
    GetUserHistoryParams params,
  ) {
    return repository.getUserLocalizationHistory(
      userIdentifier: params.userIdentifier,
      identifierType: params.identifierType,
      limit: params.limit,
    );
  }
}

class GetUserHistoryParams {
  final String userIdentifier;
  final String identifierType;
  final int limit;

  const GetUserHistoryParams({
    required this.userIdentifier,
    required this.identifierType,
    this.limit = 50,
  });
}
