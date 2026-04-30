import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/base/base_datasource.dart';
import '../../../../core/error/exceptions.dart';
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
