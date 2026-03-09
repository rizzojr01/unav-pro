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
  static const String getRoute = '/generate-instructions';

  // Locate Me Endpoints
  static const String getFloor = '/get_floor';
  static const String localizeUser = '/localize_user';
  static const String getDestinationsList = '/get_destinations_list';
  static const String getPlaceDetails = '/get_place_details';

  // Map Download Endpoints
  static const String mapDownloadCatalog = '/map_download/catalog';

  // Localization History Endpoints
  static const String localizationHistory = '/localization-history/user';

  // Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
}
