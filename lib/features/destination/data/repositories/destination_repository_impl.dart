import 'package:dartz/dartz.dart';
import 'package:fuzzy/fuzzy.dart';
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
      final multiFloor = locationConfigService.multiFloorNavigation;

      List<DestinationEntity>? allDestinations;

      // Check cache first (only for full list, not filtered searches)
      if (destinationsCacheService.hasCachedDestinations(
        place: place,
        building: building,
        floor: floor,
        multiFloor: multiFloor,
      )) {
        allDestinations = destinationsCacheService.getCachedDestinations(
          place: place,
          building: building,
          floor: floor,
          multiFloor: multiFloor,
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
            multiFloor: multiFloor,
            destinations: destinations,
          );
        }
      }

      // Filter by query if provided
      if (query.isEmpty) {
        return Right(allDestinations);
      }

      final fuse = Fuzzy<DestinationEntity>(
        allDestinations,
        options: FuzzyOptions(
          findAllMatches: true,
          tokenize: true,
          threshold: 0.4,
          keys: [
            WeightedKey(name: 'name', getter: (dest) => dest.name, weight: 0.6),
            WeightedKey(
              name: 'floor',
              getter: (dest) => dest.floor ?? '',
              weight: 0.2,
            ),
            WeightedKey(
              name: 'address',
              getter: (dest) => dest.address ?? '',
              weight: 0.2,
            ),
          ],
        ),
      );

      final results = fuse.search(query);
      final filtered = results.map((r) => r.item).toList();

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
