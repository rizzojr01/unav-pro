import '../../../../core/base/base_datasource.dart';
import '../../../../core/constants/api_routes.dart';
import '../../../../core/utils/logger.dart';
import '../models/localization_history_model.dart';
import 'package:get_it/get_it.dart';

abstract class LocalizationHistoryRemoteDataSource {
  Future<List<LocalizationHistoryModel>> getUserLocalizationHistory({
    required String userIdentifier,
    required String identifierType,
    int limit = 50,
  });
}

class LocalizationHistoryRemoteDataSourceImpl extends BaseRemoteDataSource
    implements LocalizationHistoryRemoteDataSource {
  LocalizationHistoryRemoteDataSourceImpl(super.apiClient);

  @override
  Future<List<LocalizationHistoryModel>> getUserLocalizationHistory({
    required String userIdentifier,
    required String identifierType,
    int limit = 50,
  }) async {
    try {
      final response = await apiClient.get(
        '${ApiRoutes.localizationHistory}/$userIdentifier',
        queryParameters: {
          'identifier_type': identifierType,
          'limit': limit,
        },
      );

      // Handle response as list directly
      if (response is List) {
        final List<dynamic> historyList = response;
        return LocalizationHistoryModel.fromJsonList(historyList);
      } else if (response is Map<String, dynamic>) {
        // If it's a map with 'data' key, extract the list
        if (response.containsKey('data')) {
          final List<dynamic> historyList = response['data'] as List<dynamic>;
          return LocalizationHistoryModel.fromJsonList(historyList);
        }
        throw Exception(
          'Unexpected response format: ${response.toString()}',
        );
      }
      throw Exception('Unexpected response type');
    } catch (e) {
      GetIt.instance<AppLogger>().error(
        'Error fetching localization history: $e',
        error: e,
      );
      rethrow;
    }
  }
}
