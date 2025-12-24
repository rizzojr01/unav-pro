import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/destination_entity.dart';
import '../repositories/destination_repository.dart';

class SearchDestinationsUseCase
    implements UseCase<List<DestinationEntity>, String> {
  final DestinationRepository repository;

  SearchDestinationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<DestinationEntity>>> call(String params) {
    return repository.searchDestinations(params);
  }
}

class SelectDestinationUseCase
    implements UseCase<DestinationEntity, DestinationEntity> {
  final DestinationRepository repository;

  SelectDestinationUseCase(this.repository);

  @override
  Future<Either<Failure, DestinationEntity>> call(DestinationEntity params) {
    return repository.selectDestination(params);
  }
}
