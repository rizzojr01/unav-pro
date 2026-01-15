import 'package:dartz/dartz.dart';

import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../repositories/locate_me_repository.dart';

class GetDestinationsParams {
  final String building;
  final String floor;
  final String place;
  final String? deviceId;
  final bool includeCoordinates;
  final bool unavMultifloor;

  const GetDestinationsParams({
    required this.building,
    required this.floor,
    required this.place,
    this.deviceId,
    this.includeCoordinates = true,
    this.unavMultifloor = false,
  });
}

class GetDestinationsUseCase
    implements UseCase<List<DestinationEntity>, GetDestinationsParams> {
  final LocateMeRepository repository;

  GetDestinationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<DestinationEntity>>> call(
    GetDestinationsParams params,
  ) {
    return repository.getDestinationsList(
      building: params.building,
      floor: params.floor,
      place: params.place,
      deviceId: params.deviceId,
      includeCoordinates: params.includeCoordinates,
      unavMultifloor: params.unavMultifloor,
    );
  }
}
