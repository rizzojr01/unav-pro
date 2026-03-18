import 'package:fuzzy/fuzzy.dart';
import '../../../../core/base/base_datasource.dart';
import '../../../../core/constants/api_routes.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/services/device_id_service.dart';
import '../../../../shared/services/fcm_service.dart';
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
      final fcmToken = getIt<FcmService>().token;
      final response = await post(
        ApiRoutes.getDestinationsList,
        data: {
          'building': _locationConfigService.building,
          'floor': _locationConfigService.floor,
          'place': _locationConfigService.place,
          'device_id': getIt<DeviceIdService>().getDeviceId(),
          'include_coordinates': true,
          'unav_multifloor': _locationConfigService.multiFloorNavigation,
          if (fcmToken != null) 'fcm_token': fcmToken,
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

      final fuse = Fuzzy<DestinationModel>(
        allDestinations,
        options: FuzzyOptions(
          findAllMatches: true,
          tokenize: true,
          threshold: 0.4,
          keys: [
            WeightedKey(name: 'name', getter: (dest) => dest.name, weight: 0.6),
            WeightedKey(
              name: 'floor',
              getter: (dest) => dest.floor ?? '',
              weight: 0.2,
            ),
            WeightedKey(
              name: 'address',
              getter: (dest) => dest.address ?? '',
              weight: 0.2,
            ),
          ],
        ),
      );

      final results = fuse.search(query);
      return results.map((r) => r.item).toList();
    }, errorMessage: 'Failed to search destinations');
  }
}
