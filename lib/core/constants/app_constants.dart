class AppConstants {
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Error messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'No internet connection';
  static const String cameraPermissionError = 'Camera permission denied';
  static const String locationPermissionError = 'Location permission denied';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration locationTimeout = Duration(seconds: 10);
}
