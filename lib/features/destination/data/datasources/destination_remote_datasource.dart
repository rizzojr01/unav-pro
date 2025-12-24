import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/destination_model.dart';

abstract class DestinationRemoteDataSource {
  Future<List<DestinationModel>> searchDestinations(String query);
}

class DestinationRemoteDataSourceImpl implements DestinationRemoteDataSource {
  final ApiClient apiClient;

  DestinationRemoteDataSourceImpl(this.apiClient);

  @override
  Future<List<DestinationModel>> searchDestinations(String query) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/destinations/search',
        queryParameters: {'q': query},
      );

      final List<dynamic> destinations = response['data'] as List<dynamic>;
      return destinations
          .map(
            (json) => DestinationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ServerException('Failed to search destinations: $e');
    }
  }
}
