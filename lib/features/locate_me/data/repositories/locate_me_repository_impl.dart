import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/floor_plan_entity.dart';
import '../../domain/entities/user_position_entity.dart';
import '../../domain/entities/localization_request_entity.dart';
import '../../domain/repositories/locate_me_repository.dart';
import '../datasources/locate_me_remote_datasource.dart';
import '../models/localization_request_model.dart';

class LocateMeRepositoryImpl implements LocateMeRepository {
  final LocateMeRemoteDataSource remoteDataSource;

  LocateMeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, FloorPlanEntity>> getFloorPlan({
    String? building,
    String? floor,
    String? place,
  }) async {
    try {
      final result = await remoteDataSource.getFloorPlan(
        building: building,
        floor: floor,
        place: place,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserPositionEntity>> localizeUser(
    LocalizationRequestEntity request,
  ) async {
    try {
      final requestModel = LocalizationRequestModel.fromEntity(request);
      final result = await remoteDataSource.localizeUser(requestModel);
      return Right(result);
    } catch (e) {
      // Clean up the error message by removing "Exception: " prefix if present
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      return Left(ServerFailure(errorMessage));
    }
  }

  @override
  Future<Either<Failure, List<DestinationEntity>>> getDestinationsList({
    required String building,
    required String floor,
    required String place,
    String? deviceId,
    bool includeCoordinates = true,
    bool unavMultifloor = false,
  }) async {
    try {
      final result = await remoteDataSource.getDestinationsList(
        building: building,
        floor: floor,
        place: place,
        deviceId: deviceId,
        includeCoordinates: includeCoordinates,
        unavMultifloor: unavMultifloor,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
