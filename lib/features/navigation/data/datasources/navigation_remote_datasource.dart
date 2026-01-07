import '../../../../core/base/base_datasource.dart';
import 'package:smart_sense/core/constants/api_routes.dart';
import '../models/location_model.dart';
import '../models/route_model.dart';

abstract class NavigationRemoteDataSource {
  Future<RouteModel> getRoute(LocationModel origin, LocationModel destination);
}

class NavigationRemoteDataSourceImpl extends BaseRemoteDataSource
    implements NavigationRemoteDataSource {
  NavigationRemoteDataSourceImpl(super.apiClient);

  @override
  Future<RouteModel> getRoute(
    LocationModel origin,
    LocationModel destination,
  ) async {
    return executeCall<RouteModel>(() async {
      final response = await post(
        ApiRoutes.getRoute,
        data: {'origin': origin.toJson(), 'destination': destination.toJson()},
      );

      return RouteModel.fromJson(response['data'] as Map<String, dynamic>);
    }, errorMessage: 'Failed to get route');
  }
}
