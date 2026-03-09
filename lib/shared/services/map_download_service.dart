import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../core/constants/api_routes.dart';
import 'floor_plan_cache_service.dart';

/// Result of a map catalog download attempt.
class MapDownloadResult {
  final bool success;
  final List<String> downloadedFloors;
  final String? errorMessage;

  const MapDownloadResult({
    required this.success,
    required this.downloadedFloors,
    this.errorMessage,
  });
}

/// Service that syncs all floor-plan images for a building using the
/// `/map_download/catalog` API.
///
/// Workflow:
///  1. POST /map_download/catalog → get list of floors + download URLs
///  2. For each floor whose image is not yet cached, download the PNG
///     via the individual `download_url` and store it in [FloorPlanCacheService].
///  3. Callers (LocateMeBloc, NavigationBloc) read directly from cache —
///     no per-request floor-plan fetching needed.
class MapDownloadService {
  final FloorPlanCacheService _cache;

  // Separate Dio instance for raw image downloads (bytes, no JSON interceptors)
  late final Dio _dio;

  MapDownloadService(this._cache) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    // Bypass SSL for dev server
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }

  /// Downloads all floor maps for the given [place]/[building] combination.
  ///
  /// * Clears the existing floor-plan cache for the building first so stale
  ///   images are always replaced.
  /// * Downloads each floor's PNG in parallel.
  /// * Stores results as base64 strings in [FloorPlanCacheService].
  Future<MapDownloadResult> syncMapsForBuilding({
    required String place,
    required String building,
    required String baseUrl,
  }) async {
    try {
      // ── 1. Fetch catalog ──────────────────────────────────────────────────
      final catalogDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 1),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      catalogDio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );

      final catalogResp = await catalogDio.post<Map<String, dynamic>>(
        ApiRoutes.mapDownloadCatalog,
        data: {'building': building, 'place': place},
      );

      final floors = (catalogResp.data?['floors'] as List<dynamic>?) ?? [];
      if (floors.isEmpty) {
        return const MapDownloadResult(
          success: false,
          downloadedFloors: [],
          errorMessage: 'Catalog returned no floors.',
        );
      }

      // ── 2. Clear stale cache for this building ───────────────────────────
      await _cache.clearCacheForBuilding(place: place, building: building);

      // ── 3. Download each floor image in parallel ─────────────────────────
      final downloadedFloors = <String>[];
      final errors = <String>[];

      await Future.wait(
        floors.map((floorEntry) async {
          final floorKey = floorEntry['floor'] as String? ?? '';
          final downloadUrl = floorEntry['download_url'] as String? ?? '';

          if (floorKey.isEmpty || downloadUrl.isEmpty) return;

          try {
            final response = await _dio.get<List<int>>(
              downloadUrl,
              options: Options(responseType: ResponseType.bytes),
            );

            final bytes = response.data;
            if (bytes != null && bytes.isNotEmpty) {
              final base64Image = base64Encode(bytes);
              await _cache.cacheFloorPlan(
                place: place,
                building: building,
                floor: floorKey,
                base64Image: base64Image,
              );
              downloadedFloors.add(floorKey);
            } else {
              errors.add('$floorKey: empty response');
            }
          } catch (e) {
            errors.add('$floorKey: $e');
          }
        }),
      );

      return MapDownloadResult(
        success: downloadedFloors.isNotEmpty,
        downloadedFloors: downloadedFloors,
        errorMessage: errors.isNotEmpty ? errors.join('; ') : null,
      );
    } catch (e) {
      return MapDownloadResult(
        success: false,
        downloadedFloors: [],
        errorMessage: 'Catalog fetch failed: $e',
      );
    }
  }
}
