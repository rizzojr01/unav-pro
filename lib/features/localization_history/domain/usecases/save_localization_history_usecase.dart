import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/localization_history_entity.dart';
import '../repositories/localization_history_repository.dart';

class SaveLocalizationHistoryUseCase
    implements UseCase<void, LocalizationHistoryEntity> {
  final LocalizationHistoryRepository repository;

  SaveLocalizationHistoryUseCase({required this.repository});

  @override
  Future<Either<Failure, void>> call(LocalizationHistoryEntity history) {
    return repository.saveLocalizationHistory(history);
  }
}
