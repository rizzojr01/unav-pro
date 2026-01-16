import 'package:dartz/dartz.dart';

import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/floor_plan_entity.dart';
import '../repositories/locate_me_repository.dart';

class GetFloorPlanParams {
  final String? building;
  final String? floor;
  final String? place;

  const GetFloorPlanParams({this.building, this.floor, this.place});
}

class GetFloorPlanUseCase
    implements UseCase<FloorPlanEntity, GetFloorPlanParams> {
  final LocateMeRepository repository;

  GetFloorPlanUseCase(this.repository);

  @override
  Future<Either<Failure, FloorPlanEntity>> call(GetFloorPlanParams params) {
    return repository.getFloorPlan(
      building: params.building,
      floor: params.floor,
      place: params.place,
    );
  }
}
