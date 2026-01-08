import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/location_entity.dart';
import '../entities/route_entity.dart';
import '../repositories/navigation_repository.dart';

/// Parameters for getting a route
class GetRouteParams {
  final LocationEntity? origin;
  final LocationEntity destination;

  const GetRouteParams({this.origin, required this.destination});
}

/// Use case for calculating route between two locations
class GetRouteUseCase implements UseCase<RouteEntity, GetRouteParams> {
  final NavigationRepository repository;

  GetRouteUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(GetRouteParams params) {
    return repository.getRoute(params.origin, params.destination);
  }
}
