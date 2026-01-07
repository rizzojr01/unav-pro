import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/base/base_datasource.dart';
import '../models/destination_model.dart';

abstract class DestinationRemoteDataSource {
  Future<List<DestinationModel>> searchDestinations(String query);
}

class DestinationRemoteDataSourceImpl extends BaseRemoteDataSource
    implements DestinationRemoteDataSource {
  DestinationRemoteDataSourceImpl(super.apiClient);

  @override
  Future<List<DestinationModel>> searchDestinations(String query) async {
    // TODO: Uncomment when backend is ready
    // return executeCall<List<DestinationModel>>(() async {
    //   final response = await get(
    //     ApiRoutes.searchDestinations,
    //     queryParameters: {'q': query},
    //   );
    //
    //   final List<dynamic> destinations = response['data'] as List<dynamic>;
    //   return destinations
    //       .map(
    //         (json) => DestinationModel.fromJson(json as Map<String, dynamic>),
    //       )
    //       .toList();
    // }, errorMessage: 'Failed to search destinations');

    // Mock implementation - load from local JSON
    await Future.delayed(const Duration(milliseconds: 500));
    final String jsonString = await rootBundle.loadString(
      'assets/mock_data/destinations.json',
    );
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final List<dynamic> destinations =
        jsonData['destinations'] as List<dynamic>;

    final allDestinations = destinations
        .map((json) => DestinationModel.fromJson(json as Map<String, dynamic>))
        .toList();

    // Filter by query if provided
    if (query.isEmpty) {
      return allDestinations;
    }

    return allDestinations
        .where(
          (dest) =>
              dest.name.toLowerCase().contains(query.toLowerCase()) ||
              (dest.address?.toLowerCase().contains(query.toLowerCase()) ??
                  false),
        )
        .toList();
  }
}
