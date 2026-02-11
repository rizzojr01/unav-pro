import '../../../../core/base/base_datasource.dart';
import '../../../../core/constants/api_routes.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/services/device_id_service.dart';
import '../../../../injection.dart';
import '../models/destination_model.dart';

abstract class DestinationRemoteDataSource {
  Future<List<DestinationModel>> searchDestinations(String query);
}

class DestinationRemoteDataSourceImpl extends BaseRemoteDataSource
    implements DestinationRemoteDataSource {
  final LocationConfigService _locationConfigService;

  DestinationRemoteDataSourceImpl(super.apiClient, this._locationConfigService);

  @override
  Future<List<DestinationModel>> searchDestinations(String query) async {
    return executeCall<List<DestinationModel>>(() async {
      final response = await post(
        ApiRoutes.getDestinationsList,
        data: {
          'building': _locationConfigService.building,
          'floor': _locationConfigService.floor,
          'place': _locationConfigService.place,
          'device_id': getIt<DeviceIdService>().getDeviceId(),
          'include_coordinates': true,
          'unav_multifloor': false,
        },
      );

      final List<dynamic> destinations =
          response['destinations'] as List<dynamic>;

      final allDestinations = destinations
          .map(
            (json) => DestinationModel.fromJson(json as Map<String, dynamic>),
          )
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
    }, errorMessage: 'Failed to search destinations');
  }
}
