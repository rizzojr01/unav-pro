import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/navigation_local_datasource.dart';
import '../datasources/navigation_remote_datasource.dart';
import '../models/location_model.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final NavigationLocalDataSource localDataSource;
  final NavigationRemoteDataSource remoteDataSource;

  NavigationRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, LocationEntity>> getCurrentLocation() async {
    try {
      final location = await localDataSource.getCurrentLocation();
      return Right(location);
    } on PermissionException catch (e) {
      return Left(PermissionFailure(e.message));
    } catch (e) {
      return Left(LocationFailure('Failed to get current location: $e'));
    }
  }

  @override
  Future<Either<Failure, RouteEntity>> getRoute(
    LocationEntity origin,
    LocationEntity destination,
  ) async {
    try {
      final originModel = LocationModel.fromEntity(origin);
      final destinationModel = LocationModel.fromEntity(destination);

      final route = await remoteDataSource.getRoute(
        originModel,
        destinationModel,
      );
      return Right(route);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Failed to get route: $e'));
    }
  }

  @override
  Stream<LocationEntity> watchLocation() {
    return localDataSource.watchLocation();
  }
}
