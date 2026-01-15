import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/services/destinations_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../domain/entities/destination_entity.dart';
import '../../domain/repositories/destination_repository.dart';
import '../datasources/destination_remote_datasource.dart';

class DestinationRepositoryImpl implements DestinationRepository {
  final DestinationRemoteDataSource remoteDataSource;
  final DestinationsCacheService destinationsCacheService;
  final LocationConfigService locationConfigService;

  DestinationRepositoryImpl({
    required this.remoteDataSource,
    required this.destinationsCacheService,
    required this.locationConfigService,
  });

  @override
  Future<Either<Failure, List<DestinationEntity>>> searchDestinations(
    String query,
  ) async {
    try {
      final place = locationConfigService.place;
      final building = locationConfigService.building;
      final floor = locationConfigService.floor;

      List<DestinationEntity>? allDestinations;

      // Check cache first (only for full list, not filtered searches)
      if (destinationsCacheService.hasCachedDestinations(
        place: place,
        building: building,
        floor: floor,
      )) {
        allDestinations = destinationsCacheService.getCachedDestinations(
          place: place,
          building: building,
          floor: floor,
        );
      }

      // If no cache, fetch from API
      if (allDestinations == null || allDestinations.isEmpty) {
        final destinations = await remoteDataSource.searchDestinations('');
        allDestinations = destinations;

        // Cache the full list
        if (destinations.isNotEmpty) {
          await destinationsCacheService.cacheDestinations(
            place: place,
            building: building,
            floor: floor,
            destinations: destinations,
          );
        }
      }

      // Filter by query if provided
      if (query.isEmpty) {
        return Right(allDestinations);
      }

      final filtered = allDestinations
          .where(
            (dest) =>
                dest.name.toLowerCase().contains(query.toLowerCase()) ||
                (dest.address?.toLowerCase().contains(query.toLowerCase()) ??
                    false),
          )
          .toList();

      return Right(filtered);
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
    String destinationId,
  ) async {
    try {
      // In a real app, you might want to fetch this from local storage or backend
      // For now, we'll need to implement proper destination fetching logic
      // This is a simplified implementation
      return Left(CacheFailure('Destination not found in cache'));
    } catch (e) {
      return Left(CacheFailure('Failed to select destination: $e'));
    }
  }
}
