import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/location_entity.dart';
import '../entities/route_entity.dart';
import '../repositories/navigation_repository.dart';

class GetCurrentLocationUseCase implements UseCase<LocationEntity, NoParams> {
  final NavigationRepository repository;

  GetCurrentLocationUseCase(this.repository);

  @override
  Future<Either<Failure, LocationEntity>> call(NoParams params) {
    return repository.getCurrentLocation();
  }
}

class GetRouteParams {
  final LocationEntity origin;
  final LocationEntity destination;

  GetRouteParams({required this.origin, required this.destination});
}

class GetRouteUseCase implements UseCase<RouteEntity, GetRouteParams> {
  final NavigationRepository repository;

  GetRouteUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(GetRouteParams params) {
    return repository.getRoute(params.origin, params.destination);
  }
}

class WatchLocationUseCase {
  final NavigationRepository repository;

  WatchLocationUseCase(this.repository);

  Stream<LocationEntity> call() {
    return repository.watchLocation();
  }
}
