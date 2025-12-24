import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/location_model.dart';
import '../models/route_model.dart';

abstract class NavigationRemoteDataSource {
  Future<RouteModel> getRoute(LocationModel origin, LocationModel destination);
}

class NavigationRemoteDataSourceImpl implements NavigationRemoteDataSource {
  final ApiClient apiClient;

  NavigationRemoteDataSourceImpl(this.apiClient);

  @override
  Future<RouteModel> getRoute(
    LocationModel origin,
    LocationModel destination,
  ) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/navigation/route',
        data: {'origin': origin.toJson(), 'destination': destination.toJson()},
      );

      return RouteModel.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw ServerException('Failed to get route: $e');
    }
  }
}
