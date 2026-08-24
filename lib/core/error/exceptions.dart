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

/// Turns a raw string response body into a user-presentable message.
/// Proxies answer 502/503 with a full HTML page — never show that to users.
String friendlyServerMessage(String body, int? statusCode) {
  final trimmed = body.trim();
  final looksLikeHtml =
      trimmed.startsWith('<') || trimmed.length > 200;
  if (!looksLikeHtml) return trimmed;
  switch (statusCode) {
    case 502:
    case 503:
    case 504:
      return 'The server is temporarily unavailable.\nPlease try again in a moment.';
    default:
      return 'Something went wrong on the server'
          '${statusCode != null ? ' (error $statusCode)' : ''}.\nPlease try again.';
  }
}
