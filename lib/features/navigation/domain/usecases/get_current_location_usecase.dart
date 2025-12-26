import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/location_entity.dart';
import '../repositories/navigation_repository.dart';

/// Use case for getting current device location
class GetCurrentLocationUseCase implements UseCase<LocationEntity, NoParams> {
  final NavigationRepository repository;

  GetCurrentLocationUseCase(this.repository);

  @override
  Future<Either<Failure, LocationEntity>> call(NoParams params) {
    return repository.getCurrentLocation();
  }
}
