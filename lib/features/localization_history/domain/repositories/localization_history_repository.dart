import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/localization_history_entity.dart';

abstract class LocalizationHistoryRepository {
  Future<Either<Failure, List<LocalizationHistoryEntity>>>
      getUserLocalizationHistory({
    required String userIdentifier,
    required String identifierType,
    int limit = 50,
  });
}
