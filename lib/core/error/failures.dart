import 'package:equatable/equatable.dart';

/// Base failure class
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// Server failure
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Network failure
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Validation failure
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Permission failure
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Location failure
class LocationFailure extends Failure {
  const LocationFailure(super.message);
}

/// Camera failure
class CameraFailure extends Failure {
  const CameraFailure(super.message);
}
