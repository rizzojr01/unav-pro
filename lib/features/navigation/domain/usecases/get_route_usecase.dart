import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/route_entity.dart';
import '../repositories/navigation_repository.dart';

/// Parameters for getting a route
class GetRouteParams {
  final String destinationId;
  final String place;
  final String building;
  final String floor;
  final String sessionId;
  final bool useSampleImage;
  final String base64Image;

  const GetRouteParams({
    required this.destinationId,
    required this.place,
    required this.building,
    required this.floor,
    required this.sessionId,
    required this.useSampleImage,
    required this.base64Image,
  });
}

/// Use case for calculating route between two locations
class GetRouteUseCase implements UseCase<RouteEntity, GetRouteParams> {
  final NavigationRepository repository;

  GetRouteUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(GetRouteParams params) {
    return repository.getRoute(
      destinationId: params.destinationId,
      place: params.place,
      building: params.building,
      floor: params.floor,
      sessionId: params.sessionId,
      useSampleImage: params.useSampleImage,
      base64Image: params.base64Image,
    );
  }
}
