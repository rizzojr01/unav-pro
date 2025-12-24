import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/location_entity.dart';
import '../entities/route_entity.dart';

abstract class NavigationRepository {
  Future<Either<Failure, LocationEntity>> getCurrentLocation();
  Future<Either<Failure, RouteEntity>> getRoute(
    LocationEntity origin,
    LocationEntity destination,
  );
  Stream<LocationEntity> watchLocation();
}
