import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/error/exceptions.dart';
import 'package:smart_sense/core/error/failures.dart';

/// Base repository class
/// Provides common error handling for all repositories
abstract class BaseRepository {
  /// Convert exceptions to failures
  Failure handleException(Exception exception) {
    if (exception is ServerException) {
      return ServerFailure(exception.message);
    } else if (exception is NetworkException) {
      return NetworkFailure(exception.message);
    } else if (exception is CacheException) {
      return CacheFailure(exception.message);
    } else if (exception is ValidationException) {
      return ValidationFailure(exception.message);
    } else if (exception is PermissionException) {
      return PermissionFailure(exception.message);
    } else {
      return ServerFailure('Unexpected error: ${exception.toString()}');
    }
  }

  /// Execute repository call with error handling
  Future<Either<Failure, T>> executeCall<T>(Future<T> Function() call) async {
    try {
      final result = await call();
      return Right(result);
    } on Exception catch (e) {
      return Left(handleException(e));
    }
  }
}
