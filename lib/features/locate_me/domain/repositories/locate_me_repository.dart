import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../entities/floor_plan_entity.dart';
import '../entities/user_position_entity.dart';
import '../entities/localization_request_entity.dart';

abstract class LocateMeRepository {
  /// Get floor plan image
  Future<Either<Failure, FloorPlanEntity>> getFloorPlan({
    String? building,
    String? floor,
    String? place,
  });
  

  /// Localize user on the floor plan
  Future<Either<Failure, UserPositionEntity>> localizeUser(
    LocalizationRequestEntity request,
  );

  /// Get list of destinations on the floor
  Future<Either<Failure, List<DestinationEntity>>> getDestinationsList({
    required String building,
    required String floor,
    required String place,
    String? deviceId,
    bool includeCoordinates = true,
    bool unavMultifloor = false,
  });
}
