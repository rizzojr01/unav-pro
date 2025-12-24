/// Base exception class
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, [this.statusCode]);

  @override
  String toString() =>
      'AppException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Server exception
class ServerException extends AppException {
  const ServerException(super.message, [super.statusCode]);
}

/// Cache exception
class CacheException extends AppException {
  const CacheException(super.message, [super.statusCode]);
}

/// Network exception
class NetworkException extends AppException {
  const NetworkException(super.message, [super.statusCode]);
}

/// Validation exception
class ValidationException extends AppException {
  const ValidationException(super.message, [super.statusCode]);
}

/// Permission exception
class PermissionException extends AppException {
  const PermissionException(super.message, [super.statusCode]);
}
