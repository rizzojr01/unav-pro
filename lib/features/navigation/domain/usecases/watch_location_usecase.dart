import '../entities/location_entity.dart';
import '../repositories/navigation_repository.dart';

/// Use case for watching real-time location updates
/// Note: This returns a Stream, not Either, as it's a continuous data stream
class WatchLocationUseCase {
  final NavigationRepository repository;

  WatchLocationUseCase(this.repository);

  /// Call the use case to start watching location updates
  Stream<LocationEntity> call() {
    return repository.watchLocation();
  }
}
