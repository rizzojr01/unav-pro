import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/navigation_local_datasource.dart';
import '../datasources/navigation_remote_datasource.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final NavigationLocalDataSource localDataSource;
  final NavigationRemoteDataSource remoteDataSource;

  NavigationRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, RouteEntity>> getRoute({
    required String destinationId,
    required String place,
    required String building,
    required String floor,
    required String sessionId,
    required bool useSampleImage,
    required String base64Image,
    bool saveFrame = false,
    bool multiFloorNavigation = true,
    Map<String, dynamic>? imageCompression,
    Map<String, dynamic>? userPickedCoordinates,
  }) async {
    try {
      final routeModel = await remoteDataSource.getRoute(
        destinationId: destinationId,
        place: place,
        building: building,
        floor: floor,
        sessionId: sessionId,
        useSampleImage: useSampleImage,
        base64Image: base64Image,
        saveFrame: saveFrame,
        multiFloorNavigation: multiFloorNavigation,
        imageCompression: imageCompression,
        userPickedCoordinates: userPickedCoordinates,
      );

      return Right(routeModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // For regular Exception, extract message
      final message = e.toString().replaceFirst('Exception: ', '');
      return Left(ServerFailure(message));
    }
  }
}
