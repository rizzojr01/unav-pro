import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiRoutes {
  // Base URL
  static String get baseUrl => dotenv.get('BASE_URL');

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
