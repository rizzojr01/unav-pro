class AppConstants {
  // API
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://your-api.com/api',
  );

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Routes
  static const String cameraRoute = '/camera';
  static const String destinationRoute = '/destination';
  static const String navigationRoute = '/navigation';

  // Error messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'No internet connection';
  static const String cameraPermissionError = 'Camera permission denied';
  static const String locationPermissionError = 'Location permission denied';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration locationTimeout = Duration(seconds: 10);
}
