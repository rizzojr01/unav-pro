import '../../../../core/base/base_datasource.dart';
import '../../../../core/constants/api_routes.dart';
import '../../../destination/data/models/destination_model.dart';
import '../models/floor_plan_model.dart';
import '../models/user_position_model.dart';
import '../models/localization_request_model.dart';

abstract class LocateMeRemoteDataSource {
  /// Get floor plan image from the backend
  Future<FloorPlanModel> getFloorPlan({
    String? building,
    String? floor,
    String? place,
  });

  /// Localize user position based on captured image
  Future<UserPositionModel> localizeUser(LocalizationRequestModel request);

  /// Get list of destinations for the floor
  Future<List<DestinationModel>> getDestinationsList({
    required String building,
    required String floor,
    required String place,
    String? deviceId,
    bool includeCoordinates = true,
    bool unavMultifloor = false,
  });
}

class LocateMeRemoteDataSourceImpl extends BaseRemoteDataSource
    implements LocateMeRemoteDataSource {
  LocateMeRemoteDataSourceImpl(super.apiClient);

  @override
  Future<FloorPlanModel> getFloorPlan({
    String? building,
    String? floor,
    String? place,
  }) async {
    return executeCall<FloorPlanModel>(() async {
      final response = await get(
        ApiRoutes.getFloor,
        queryParameters: {
          if (building != null) 'building': building,
          if (floor != null) 'floor': floor,
          if (place != null) 'place': place,
        },
      );
      return FloorPlanModel.fromJson(response);
    }, errorMessage: 'Failed to get floor plan');
  }

  @override
  Future<UserPositionModel> localizeUser(
    LocalizationRequestModel request,
  ) async {
    try {
      final response = await post(
        ApiRoutes.localizeUser,
        data: request.toJson(),
      );
      return UserPositionModel.fromJson(response);
    } on LocalizationFailedException catch (e) {
      // Re-throw with the proper error message from the API
      throw Exception(e.message);
    } catch (e) {
      // Handle other exceptions
      if (e is Exception) rethrow;
      throw Exception('Failed to localize user');
    }
  }

  @override
  Future<List<DestinationModel>> getDestinationsList({
    required String building,
    required String floor,
    required String place,
    String? deviceId,
    bool includeCoordinates = true,
    bool unavMultifloor = false,
  }) async {
    return executeCall<List<DestinationModel>>(() async {
      final response = await post(
        ApiRoutes.getDestinationsList,
        data: {
          'building': building,
          'floor': floor,
          'place': place,
          'device_id':
              deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
          'include_coordinates': includeCoordinates,
          'unav_multifloor': unavMultifloor,
        },
      );
      return DestinationModel.fromJsonList(response);
    }, errorMessage: 'Failed to get destinations list');
  }
}
