import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/route_entity.dart';

abstract class NavigationRepository {
  Future<Either<Failure, RouteEntity>> getRoute({
    required String destinationId,
    required String place,
    required String building,
    required String floor,
    required String sessionId,
    required bool useSampleImage,
    required String base64Image,
    Map<String, dynamic>? imageCompression,
  });
}
