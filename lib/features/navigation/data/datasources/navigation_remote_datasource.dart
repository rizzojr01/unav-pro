import '../../../../core/base/base_datasource.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../injection.dart';
import '../../../../shared/services/fcm_service.dart';
import 'package:smart_sense/core/constants/api_routes.dart';
import '../models/route_model.dart';

abstract class NavigationRemoteDataSource {
  Future<RouteModel> getRoute({
    required String destinationId,
    required String place,
    required String building,
    required String floor,
    required String sessionId,
    required bool useSampleImage,
    required String base64Image,
    bool saveFrame = false,
    bool multiFloorNavigation = true,
    Map<String, dynamic>? imageCompression,
    Map<String, dynamic>? userPickedCoordinates,
    double? heading,
    double offsetInMeters = 0.0,
  });
}

class NavigationRemoteDataSourceImpl extends BaseRemoteDataSource
    implements NavigationRemoteDataSource {
  NavigationRemoteDataSourceImpl(super.apiClient);

  @override
  Future<RouteModel> getRoute({
    required String destinationId,
    required String place,
    required String building,
    required String floor,
    required String sessionId,
    required bool useSampleImage,
    required String base64Image,
    bool saveFrame = false,
    bool multiFloorNavigation = true,
    Map<String, dynamic>? imageCompression,
    Map<String, dynamic>? userPickedCoordinates,
    double? heading,
    double offsetInMeters = 0.0,
  }) async {
    return executeCall<RouteModel>(() async {
      final logger = getIt<AppLogger>();
      final fcmToken = getIt<FcmService>().token;

      // Ensure 'enabled': true is present if coordinates are picked
      final Map<String, dynamic> payload = {
        'destination_id': destinationId,
        'place': place,
        'building': building,
        'floor': floor,
        'session_id': sessionId,
        'use_sample_image': useSampleImage,
        'base_64_image': base64Image,
        'relocalize': true,
        'saveframe': saveFrame,
        'shorten_vlm_response': true,
        'speakVlmFirst': true,
        'unav_multifloor': multiFloorNavigation,
        'use_vlm': false,
        'offset_in_meters': offsetInMeters,
        'image_compression': imageCompression,
        'user_picked_coordinates': userPickedCoordinates != null
            ? {...userPickedCoordinates, 'enabled': true}
            : null,
        'heading': heading,
        if (fcmToken != null) 'fcm_token': fcmToken,
      };

      final payloadSizeKb =
          (payload.toString().length) / 1024; // Rough estimate
      logger.info(
        '📤 Uploading Navigation Request: ${payloadSizeKb.toStringAsFixed(2)} KB',
      );

      final response = await post(ApiRoutes.getRoute, data: payload);

      // Log only the orientation from the backend
      dynamic orientation;
      if (response['ang'] != null) {
        orientation = response['ang'];
      } else {
        final steps = response['multifloor_navigation_steps'] as List<dynamic>?;
        if (steps != null && steps.isNotEmpty) {
          final firstFloorSteps = steps.first['steps'] as List<dynamic>?;
          if (firstFloorSteps != null && firstFloorSteps.isNotEmpty) {
            orientation = firstFloorSteps.first['from']?['ang'];
          }
        }
      }

      if (orientation != null) {
        logger.info('Backend Orientation (Route): $orientation°');
      }

      final multiFloorSteps =
          response['multifloor_navigation_steps'] as List<dynamic>?;
      if (multiFloorSteps == null || multiFloorSteps.isEmpty) {
        final instructions = response['instructions'] as List<dynamic>?;
        final errorMessage = (instructions != null && instructions.isNotEmpty)
            ? instructions.first.toString()
            : 'Unable to generate navigation instructions. Please try again.';
        throw ServerException(errorMessage);
      }

      return RouteModel.fromJson(response);
    }, errorMessage: 'Failed to get route');
  }
}
