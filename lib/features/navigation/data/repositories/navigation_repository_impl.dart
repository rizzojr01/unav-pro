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
      // For now, return a mock location to bypass sensor/platform issues
      return Right(
        LocationEntity(
          latitude: 27.7172,
          longitude: 85.3240,
          timestamp: DateTime.now(),
        ),
      );
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
      // For now, return a mock route to bypass backend issues
      await Future.delayed(const Duration(milliseconds: 1500));

      final mockWaypoints = [
        origin,
        LocationEntity(
          latitude: origin.latitude + 0.0001,
          longitude: origin.longitude + 0.0001,
          timestamp: DateTime.now(),
        ),
        LocationEntity(
          latitude: origin.latitude + 0.0002,
          longitude: origin.longitude - 0.0001,
          timestamp: DateTime.now(),
        ),
        destination,
      ];

      final mockRoute = RouteEntity(
        entityId: 'mock-route-${DateTime.now().millisecondsSinceEpoch}',
        origin: origin,
        destination: destination,
        waypoints: mockWaypoints,
        distanceInMeters: 45.5,
        durationInSeconds: 120,
      );

      return Right(mockRoute);
    } catch (e) {
      return Left(ServerFailure('Failed to generate mock route: $e'));
    }
  }

  @override
  Stream<LocationEntity> watchLocation() {
    return localDataSource.watchLocation();
  }
}
