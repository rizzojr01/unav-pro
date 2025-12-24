import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/destination_entity.dart';
import '../../domain/repositories/destination_repository.dart';
import '../datasources/destination_remote_datasource.dart';

class DestinationRepositoryImpl implements DestinationRepository {
  final DestinationRemoteDataSource remoteDataSource;

  DestinationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<DestinationEntity>>> searchDestinations(
    String query,
  ) async {
    try {
      final destinations = await remoteDataSource.searchDestinations(query);
      return Right(destinations);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to search destinations: $e'));
    }
  }

  @override
  Future<Either<Failure, DestinationEntity>> selectDestination(
    DestinationEntity destination,
  ) async {
    try {
      // In a real app, you might want to save this to local storage or send to backend
      return Right(destination);
    } catch (e) {
      return Left(CacheFailure('Failed to select destination: $e'));
    }
  }
}
