import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/base/base_datasource.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../injection.dart';
import '../../../../shared/services/fcm_service.dart';
import 'package:smart_sense/core/constants/api_routes.dart';
import '../models/route_model.dart';

// ─── Temporary mock ──────────────────────────────────────────────────────────
// Set to true while the backend is down. Flip back to false when it's up.
const bool _kUseMockRoute = true;

const Map<String, dynamic> _kMockRouteJson = {
  'id': 'mock-route-001',
  'meters_per_pixel': null, // will use app default (0.05)
  'multifloor_navigation_steps': [
    {
      'floor': '1', // TODO: replace with your real floor key
      'steps': [
        {
          'from': {'x': 1739.804452917344, 'y': 1146.1793065244783},
          'to': {'x': 1739.804452917344, 'y': 1146.1793065244783},
          'distance_meters': 0.0,
          'distance_feet': 0,
        },
        {
          'from': {'x': 1739.804452917344, 'y': 1146.1793065244783},
          'to': {'x': 1970.8333333333335, 'y': 1156.25},
          'distance_meters': 5.101018168115349,
          'distance_feet': 17,
        },
        {
          'from': {'x': 1970.8333333333335, 'y': 1156.25},
          'to': {'x': 1979.1666666666667, 'y': 1437.5},
          'distance_meters': 6.206710112656697,
          'distance_feet': 20,
        },
        {
          'from': {'x': 1979.1666666666667, 'y': 1437.5},
          'to': {'x': 5041.666666666667, 'y': 1431.25},
          'distance_meters': 67.55467040171544,
          'distance_feet': 222,
        },
        {
          'from': {'x': 5041.666666666667, 'y': 1431.25},
          'to': {'x': 4937.209302325581, 'y': 1134.8837209302326},
          'distance_meters': 6.931614834242284,
          'distance_feet': 23,
        },
      ],
    },
  ],
};
// ─────────────────────────────────────────────────────────────────────────────

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
    double offsetInMeters = 0.0,
    double? heading,
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
    double offsetInMeters = 0.0,
    double? heading,
  }) async {
    if (_kUseMockRoute) {
      debugPrint('[NavigationDataSource] Using mock route (backend offline).');
      return RouteModel.fromJson(_kMockRouteJson);
    }

    return executeCall<RouteModel>(() async {
      final fcmToken = getIt<FcmService>().token;

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
        'user_picked_coordinates': userPickedCoordinates,
        'fcm_token': ?fcmToken,
      };

      final response = await post(ApiRoutes.getRoute, data: payload);

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
