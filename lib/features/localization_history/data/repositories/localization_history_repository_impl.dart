import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/localization_history_entity.dart';
import '../../domain/repositories/localization_history_repository.dart';
import '../datasources/localization_history_remote_datasource.dart';

class LocalizationHistoryRepositoryImpl
    implements LocalizationHistoryRepository {
  final LocalizationHistoryRemoteDataSource remoteDataSource;

  LocalizationHistoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<LocalizationHistoryEntity>>>
      getUserLocalizationHistory({
    required String userIdentifier,
    required String identifierType,
    int limit = 50,
  }) async {
    try {
      final result = await remoteDataSource.getUserLocalizationHistory(
        userIdentifier: userIdentifier,
        identifierType: identifierType,
        limit: limit,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
