import 'package:dartz/dartz.dart';
import '../error/failures.dart';

/// Base class for all use cases
/// [T] is the return type
/// [Params] is the input parameters type
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Use case with no parameters
class NoParams {
  const NoParams();
}
