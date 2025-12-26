import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/error/failures.dart';

/// Base use case class with parameters
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Base use case class with parameters (alias for backward compatibility)
abstract class BaseUseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Base use case class without parameters
abstract class BaseUseCaseNoParams<T> {
  Future<Either<Failure, T>> call();
}

/// Use case with no parameters (for convenience)
class NoParams {
  const NoParams();
}
