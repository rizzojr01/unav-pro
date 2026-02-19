import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/localization_history_entity.dart';
import '../../domain/repositories/localization_history_repository.dart';
import '../datasources/localization_history_remote_datasource.dart';
import '../datasources/localization_history_local_datasource.dart';
import '../models/localization_history_model.dart';

class LocalizationHistoryRepositoryImpl
    implements LocalizationHistoryRepository {
  final LocalizationHistoryRemoteDataSource remoteDataSource;
  final LocalizationHistoryLocalDataSource localDataSource;

  LocalizationHistoryRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<LocalizationHistoryEntity>>>
  getUserLocalizationHistory({
    required String userIdentifier,
    required String identifierType,
    int limit = 50,
  }) async {
    try {
      // Prioritize local history as requested
      final localHistory = await localDataSource.getLocalizationHistory();
      if (localHistory.isNotEmpty) {
        return Right(localHistory);
      }

      // If local is empty, fallback to remote (optional, but keep for completeness)
      final remoteHistory = await remoteDataSource.getUserLocalizationHistory(
        userIdentifier: userIdentifier,
        identifierType: identifierType,
        limit: limit,
      );

      // Cache remote history to local if any
      for (final item in remoteHistory.reversed) {
        await localDataSource.saveLocalizationHistory(item);
      }

      return Right(remoteHistory);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to fetch localization history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveLocalizationHistory(
    LocalizationHistoryEntity history,
  ) async {
    try {
      await localDataSource.saveLocalizationHistory(
        LocalizationHistoryModel.fromEntity(history),
      );
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to save navigation history locally'));
    }
  }
}
