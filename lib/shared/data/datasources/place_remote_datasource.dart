import '../../../../core/base/base_datasource.dart';
import '../../../../core/constants/api_routes.dart';
import '../models/place_model.dart';

abstract class PlaceRemoteDataSource {
  /// Get list of all places with their buildings and floors
  Future<List<PlaceModel>> getPlaceDetails();
}

class PlaceRemoteDataSourceImpl extends BaseRemoteDataSource
    implements PlaceRemoteDataSource {
  PlaceRemoteDataSourceImpl(super.apiClient);

  @override
  Future<List<PlaceModel>> getPlaceDetails() async {
    return executeCall<List<PlaceModel>>(() async {
      final response = await apiClient.get<List<dynamic>>(
        ApiRoutes.getPlaceDetails,
      );
      return PlaceModel.fromJsonList(response);
    }, errorMessage: 'Failed to get place details');
  }
}
