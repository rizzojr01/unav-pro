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
          'base_64_image': '',
          'relocalize': false,
          'saveframe': false,
          'shorten_vlm_response': true,
          'speakVlmFirst': true,
          'unav_multifloor': false,
          'use_vlm': false,
        },
      );

      // Check if navigation_steps is empty - this indicates an error
      final navigationSteps = response['navigation_steps'] as List<dynamic>?;
      if (navigationSteps == null || navigationSteps.isEmpty) {
        // Extract error message from instructions
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
