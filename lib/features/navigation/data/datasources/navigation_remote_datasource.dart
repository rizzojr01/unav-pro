import '../../../../core/base/base_datasource.dart';
import '../../../../core/error/exceptions.dart';
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
  }) async {
    return executeCall<RouteModel>(() async {
      final response = await post(
        ApiRoutes.getRoute,
        data: {
          'destination_id': destinationId,
          'place': place,
          'building': building,
          'floor': floor,
          'session_id': sessionId,
          'use_sample_image': useSampleImage,
          'base_64_image': base64Image,
          'relocalize': false,
          'saveframe': saveFrame,
          'shorten_vlm_response': true,
          'speakVlmFirst': true,
          'unav_multifloor': multiFloorNavigation,
          'use_vlm': false,
          if (imageCompression != null) 'image_compression': imageCompression,
          if (userPickedCoordinates != null)
            'user_picked_coordinates': userPickedCoordinates,
        },
      );

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
