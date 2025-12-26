import 'package:dartz/dartz.dart';
import '../../../../core/base/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/destination_entity.dart';
import '../repositories/destination_repository.dart';

/// Use case for searching destinations by query
class SearchDestinationsUseCase
    implements UseCase<List<DestinationEntity>, String> {
  final DestinationRepository repository;

  SearchDestinationsUseCase(this.repository);

  @override
  Future<Either<Failure, List<DestinationEntity>>> call(String params) {
    return repository.searchDestinations(params);
  }
}
