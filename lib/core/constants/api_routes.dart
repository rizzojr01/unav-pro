class ApiRoutes {
  // Base URL
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://your-api.com/api',
  );

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String me = '/auth/me';

  // Camera Endpoints
  static const String uploadPhoto = '/photos/upload';

  // Destination Endpoints
  static const String searchDestinations = '/destinations/search';

  // Navigation Endpoints
  static const String getRoute = '/navigation/route';

  // Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
}
