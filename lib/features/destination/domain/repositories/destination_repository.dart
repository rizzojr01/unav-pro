import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/destination_entity.dart';

abstract class DestinationRepository {
  Future<Either<Failure, List<DestinationEntity>>> searchDestinations(
    String query,
  );
  Future<Either<Failure, DestinationEntity>> selectDestination(
    DestinationEntity destination,
  );
}
