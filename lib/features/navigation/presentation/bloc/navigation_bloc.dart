import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../../shared/services/destinations_cache_service.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../../locate_me/domain/usecases/get_destinations_usecase.dart';
import '../../../localization_history/domain/entities/localization_history_entity.dart';
import '../../../localization_history/domain/usecases/save_localization_history_usecase.dart';
import '../../../../shared/services/device_id_service.dart';
import '../../../ar_navigation/domain/repositories/ar_pose_repository.dart';
import '../../../../core/utils/logger.dart';
import '../../../../injection.dart';
import '../../domain/usecases/get_route_usecase.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final GetRouteUseCase getRouteUseCase;
  final GetDestinationsUseCase getDestinationsUseCase;
  final LocationConfigService locationConfigService;
  final FloorPlanCacheService floorPlanCacheService;
  final DestinationsCacheService destinationsCacheService;
  final SaveLocalizationHistoryUseCase saveLocalizationHistoryUseCase;
  final DeviceIdService deviceIdService;
  final ArPoseRepository arPoseRepository;

  NavigationBloc({
    required this.getRouteUseCase,
    required this.getDestinationsUseCase,
    required this.locationConfigService,
    required this.floorPlanCacheService,
    required this.destinationsCacheService,
    required this.saveLocalizationHistoryUseCase,
    required this.deviceIdService,
    required this.arPoseRepository,
  }) : super(const NavigationInitial()) {
    on<InitializeNavigationEvent>(_onInitializeNavigation);
  }

  Future<void> _onInitializeNavigation(
    InitializeNavigationEvent event,
    Emitter<NavigationState> emit,
  ) async {
    final place = locationConfigService.place;
    final building = locationConfigService.building;
    final floor = event.pickedFloor ?? locationConfigService.floor;
    final destinationId = event.destination.destinationId;
    // Use the stable device ID as session identifier so the backend always
    // sees the same user/device across every request from this device.
    final sessionId = deviceIdService.getDeviceId();
    final useSampleImage = locationConfigService.useSampleImage;

    emit(const NavigationLoading(message: 'Preparing your route...'));
    double? headingAtStart = await arPoseRepository.getCurrentHeading();

    // Fallback: If ArPoseRepository fails, try getting heading from userCoords
    if (headingAtStart == null && event.userPickedCoordinates != null) {
      headingAtStart = (event.userPickedCoordinates!['heading'] as num?)
          ?.toDouble();
      getIt<AppLogger>().info(
        '🧭 NavigationBloc: headingAtStart fallback to userCoords: $headingAtStart',
      );
    }

    getIt<AppLogger>().info(
      '🧭 NavigationBloc: headingAtStart (Ref Head) final value: $headingAtStart',
    );

    // ── Step 1: Read floor plan from cache (pre-loaded by MapDownloadService) ─
    // Maps are downloaded when the building is selected; no per-request fetch.
    final floorPlanBase64 = await floorPlanCacheService
        .getCachedFloorPlanBase64(
          place: place,
          building: building,
          floor: floor,
        );

    if (floorPlanBase64 == null || floorPlanBase64.isEmpty) {
      emit(
        const NavigationError(
          'Floor map not available. Please go to Settings and re-select your '
          'building to download the latest maps.',
        ),
      );
      return;
    }

    // ── Step 2: Prepare the localization image ────────────────────────────────
    final useAlternate = locationConfigService.useAlternateSampleImage;
    bool effectiveUseSample = useSampleImage;
    String base64Image = '';

    if (useAlternate) {
      try {
        final byteData = await rootBundle.load(
          locationConfigService.alternateSampleImagePath,
        );
        base64Image = base64Encode(byteData.buffer.asUint8List());
        effectiveUseSample = false;
      } catch (e) {
        getIt<AppLogger>().error(
          'NavigationBloc: Alternate image loading failed: $e',
        );
      }
    } else if (event.imagePath != null &&
        event.imagePath!.isNotEmpty &&
        !useSampleImage) {
      try {
        final imageFile = File(event.imagePath!);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          base64Image = base64Encode(bytes);
          getIt<AppLogger>().info(
            '📸 NavigationBloc: Encoded image from ${event.imagePath} (${bytes.length} bytes)',
          );
        }
      } catch (e) {
        getIt<AppLogger>().error('NavigationBloc: Image processing failed: $e');
      }
    }

    // ── Step 3: Get route ─────────────────────────────────────────────────────
    emit(const NavigationLoading(message: 'Calculating route...'));

    final dynamic userCoords = event.userPickedCoordinates;
    final bool isManualPin =
        userCoords != null && userCoords['enabled'] == true;
    final double? capturedHeading = (userCoords != null)
        ? (userCoords['heading'] as num?)?.toDouble()
        : null;

    final Map<String, dynamic>? userPickedCoordinates = isManualPin
        ? (userCoords as Map<String, dynamic>)
        : {'x': 0.0, 'y': 0.0, 'heading': 0.0, 'enabled': false};

    final routeResult = await getRouteUseCase(
      GetRouteParams(
        destinationId: destinationId,
        place: place,
        building: building,
        floor: floor,
        sessionId: sessionId,
        useSampleImage: effectiveUseSample,
        base64Image: base64Image,
        saveFrame: locationConfigService.saveFrame,
        multiFloorNavigation: locationConfigService.multiFloorNavigation,
        imageCompression: {
          'enable_compression': locationConfigService.enableCompression,
          'max_height': locationConfigService.maxHeight,
          'max_width': locationConfigService.maxWidth,
          'quality': locationConfigService.imageQuality,
        },
        userPickedCoordinates: userPickedCoordinates,
        offsetInMeters: locationConfigService.offsetInMeters,
        heading: isManualPin ? null : capturedHeading,
      ),
    );

    await routeResult.fold(
      (failure) async => emit(NavigationError(failure.message)),
      (route) async {
        final actualStartingFloor = route.multiFloorSteps.isNotEmpty
            ? route.multiFloorSteps.first.floor
            : floor;

        // ── Step 4: Load destinations from cache for all route floors ─────────
        List<DestinationEntity> destinations = [];
        final Map<String, List<DestinationEntity>> destinationsByFloor = {};

        // Normalise floor string for comparison: "17_floor" → "17"
        String normaliseFloor(String f) =>
            f.replaceAll('_floor', '').replaceAll('_', '').trim().toLowerCase();

        // Fetch destinations for a floor — cache-first, API fallback.
        // The multifloor API returns ALL floors; we group and cache per-floor.
        Future<List<DestinationEntity>> fetchDestsForFloor(
          String floorKey,
        ) async {
          final cached = destinationsCacheService.getCachedDestinations(
            place: place,
            building: building,
            floor: floorKey,
            multiFloor: locationConfigService.multiFloorNavigation,
          );
          if (cached != null && cached.isNotEmpty) return cached;

          final result = await getDestinationsUseCase(
            GetDestinationsParams(
              building: building,
              floor: floorKey,
              place: place,
              includeCoordinates: true,
              unavMultifloor: locationConfigService.multiFloorNavigation,
            ),
          );
          final allDests = result.getOrElse(() => []);
          if (allDests.isEmpty) return [];

          // Group by each destination's own floor field
          final Map<String, List<DestinationEntity>> grouped = {};
          for (final d in allDests) {
            final normDest = d.floor != null
                ? normaliseFloor(d.floor!)
                : normaliseFloor(floorKey);
            grouped.putIfAbsent(normDest, () => []).add(d);
          }

          // Cache each floor's slice
          for (final entry in grouped.entries) {
            final rawKey = route.multiFloorSteps
                .map((s) => s.floor)
                .firstWhere(
                  (f) => normaliseFloor(f) == entry.key,
                  orElse: () => floorKey,
                );
            await destinationsCacheService.cacheDestinations(
              place: place,
              building: building,
              floor: rawKey,
              multiFloor: locationConfigService.multiFloorNavigation,
              destinations: entry.value,
            );
          }

          return grouped[normaliseFloor(floorKey)] ?? [];
        }

        await Future.wait(
          route.multiFloorSteps.map((step) async {
            final floorKey = step.floor;
            final dests = await fetchDestsForFloor(floorKey);
            if (dests.isNotEmpty) {
              destinationsByFloor[floorKey] = dests;
              if (floorKey == actualStartingFloor) {
                destinations = dests;
              }
            }
          }),
        );

        // ── Step 5: Build floorPlansByFloor from cache ────────────────────────
        // All floor plans were pre-downloaded by MapDownloadService; just read.
        final Map<String, String> floorPlansByFloor = {};
        for (final step in route.multiFloorSteps) {
          final cached = await floorPlanCacheService.getCachedFloorPlanBase64(
            place: place,
            building: building,
            floor: step.floor,
          );
          if (cached != null && cached.isNotEmpty) {
            floorPlansByFloor[step.floor] = cached;
          }
        }

        // ── Step 6: Save navigation history ──────────────────────────────────
        await saveLocalizationHistoryUseCase(
          LocalizationHistoryEntity(
            historyId: DateTime.now().millisecondsSinceEpoch,
            userIdentifier: deviceIdService.getDeviceId(),
            identifierType: 'device',
            sessionId: sessionId,
            destinationId: destinationId,
            destinationName: event.destination.name,
            building: building,
            floor: actualStartingFloor,
            place: place,
            createdAt: DateTime.now(),
          ),
        );

        // --- Final Heading Capture (Plot Heading) ---
        // Try getting heading from simple compass (same as capture)
        double? finalPlotHeading;
        try {
          final compassEvent = await FlutterCompass.events?.first.timeout(
            const Duration(milliseconds: 500),
          );
          finalPlotHeading = compassEvent?.heading;
          if (finalPlotHeading != null) {
            getIt<AppLogger>().info(
              '🧭 NavigationBloc: finalPlotHeading from Compass: $finalPlotHeading',
            );
          }
        } catch (e) {
          getIt<AppLogger>().error(
            '🧭 NavigationBloc: Compass failed, trying AR Repository: $e',
          );
        }

        // Fallback to AR Repository if compass failed
        if (finalPlotHeading == null) {
          for (int i = 0; i < 3; i++) {
            finalPlotHeading = await arPoseRepository.getCurrentHeading();
            if (finalPlotHeading != null) break;
            await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
          }
        }

        getIt<AppLogger>().info(
          '🧭 NavigationBloc: finalPlotHeading final: $finalPlotHeading',
        );

        emit(
          NavigationReady(
            currentLocation: route.origin.copyWith(floor: actualStartingFloor),
            route: route,
            floorPlanBase64:
                floorPlansByFloor[actualStartingFloor] ?? floorPlanBase64,
            destinations: destinations,
            floorPlansByFloor: floorPlansByFloor,
            destinationsByFloor: destinationsByFloor,
            metersPerPixel: route.metersPerPixel,
            headingAtStart: finalPlotHeading ?? headingAtStart,
            capturedReferenceHeading: capturedHeading,
          ),
        );
      },
    );
  }
}
