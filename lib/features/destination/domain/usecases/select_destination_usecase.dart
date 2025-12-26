import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/destination_entity.dart';
import '../repositories/destination_repository.dart';

/// Use case for selecting a destination
class SelectDestinationUseCase implements UseCase<DestinationEntity, String> {
  final DestinationRepository repository;

  SelectDestinationUseCase(this.repository);

  @override
  Future<Either<Failure, DestinationEntity>> call(String destinationId) {
    return repository.selectDestination(destinationId);
  }
}
