import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/base/base_datasource.dart';
import '../../../core/constants/api_routes.dart';
import '../../../injection.dart';
import '../../services/fcm_service.dart';
import '../models/place_model.dart';

abstract class PlaceRemoteDataSource {
  /// Get list of all places with their buildings and floors
  Future<List<PlaceModel>> getPlaceDetails();
}

class PlaceRemoteDataSourceImpl extends BaseRemoteDataSource
    implements PlaceRemoteDataSource {
  PlaceRemoteDataSourceImpl(super.apiClient);

  static const _cacheKey = 'place_details_cache';
  static const _cacheTsKey = 'place_details_cache_ts';
  static const _cacheTtl = Duration(hours: 24);

  /// Drop the cached catalog. Wired to the "clear cache" button.
  static Future<void> clearCachedPlaces() async {
    final prefs = getIt<SharedPreferences>();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTsKey);
  }

  @override
  Future<List<PlaceModel>> getPlaceDetails() async {
    final prefs = getIt<SharedPreferences>();
    final cached = prefs.getString(_cacheKey);
    final ts = prefs.getInt(_cacheTsKey);
    final fresh = cached != null &&
        ts != null &&
        DateTime.now().millisecondsSinceEpoch - ts < _cacheTtl.inMilliseconds;

    if (fresh) {
      try {
        return PlaceModel.fromJsonList(jsonDecode(cached) as List<dynamic>);
      } catch (_) {
        // Corrupt cache — fall through to the network.
      }
    }

    try {
      return await executeCall<List<PlaceModel>>(() async {
        final fcmToken = getIt<FcmService>().token;
        final response = await apiClient.get<List<dynamic>>(
          ApiRoutes.getPlaceDetails,
          queryParameters: {
            if (fcmToken != null) 'fcm_token': fcmToken,
          },
        );
        await prefs.setString(_cacheKey, jsonEncode(response));
        await prefs.setInt(
          _cacheTsKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        return PlaceModel.fromJsonList(response);
      }, errorMessage: 'Failed to get place details');
    } catch (_) {
      // Network failed (e.g. server cold start). A stale cache beats an
      // error screen — serve it and let the next call retry the network.
      if (cached != null) {
        try {
          return PlaceModel.fromJsonList(jsonDecode(cached) as List<dynamic>);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
