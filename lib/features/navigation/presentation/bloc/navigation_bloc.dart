import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/destinations_cache_service.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../../locate_me/domain/usecases/get_floor_plan_usecase.dart';
import '../../../locate_me/domain/usecases/get_destinations_usecase.dart';
import '../../../localization_history/domain/entities/localization_history_entity.dart';
import '../../../localization_history/domain/usecases/save_localization_history_usecase.dart';
import '../../../../shared/services/device_id_service.dart';
import '../../domain/usecases/get_route_usecase.dart';
import 'navigation_event.dart';
import 'navigation_state.dart';

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  final GetRouteUseCase getRouteUseCase;
  final GetFloorPlanUseCase getFloorPlanUseCase;
  final GetDestinationsUseCase getDestinationsUseCase;
  final LocationConfigService locationConfigService;
  final FloorPlanCacheService floorPlanCacheService;
  final DestinationsCacheService destinationsCacheService;
  final SaveLocalizationHistoryUseCase saveLocalizationHistoryUseCase;
  final DeviceIdService deviceIdService;

  NavigationBloc({
    required this.getRouteUseCase,
    required this.getFloorPlanUseCase,
    required this.getDestinationsUseCase,
    required this.locationConfigService,
    required this.floorPlanCacheService,
    required this.destinationsCacheService,
    required this.saveLocalizationHistoryUseCase,
    required this.deviceIdService,
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
    final sessionId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    final useSampleImage = locationConfigService.useSampleImage;

    emit(const NavigationLoading(message: 'Loading floor plan...'));

    String? floorPlanBase64;
    String? floorPlanError;

    // Step 1: Check cache first
    if (floorPlanCacheService.hasCachedFloorPlan(
      place: place,
      building: building,
      floor: floor,
    )) {
      // Use cached floor plan
      floorPlanBase64 = floorPlanCacheService.getCachedFloorPlanBase64(
        place: place,
        building: building,
        floor: floor,
      );
    } else {
      // Fetch from API
      final floorPlanResult = await getFloorPlanUseCase(
        GetFloorPlanParams(building: building, floor: floor, place: place),
      );

      await floorPlanResult.fold(
        (failure) async {
          floorPlanError = failure.message;
        },
        (floorPlan) async {
          floorPlanBase64 = floorPlan.base64Image;
          // Cache the floor plan for future use
          if (floorPlanBase64 != null && floorPlanBase64!.isNotEmpty) {
            await floorPlanCacheService.cacheFloorPlan(
              place: place,
              building: building,
              floor: floor,
              base64Image: floorPlanBase64!,
            );
          }
        },
      );
    }

    // If floor plan failed and no cache, show error
    if (floorPlanBase64 == null || floorPlanBase64!.isEmpty) {
      emit(
        NavigationError(
          floorPlanError ?? 'Failed to load floor plan. Please try again.',
        ),
      );
      return;
    }

    final useAlternate = locationConfigService.useAlternateSampleImage;
    bool effectiveUseSample = useSampleImage;

    String base64Image = '';

    if (useAlternate) {
      try {
        final byteData = await rootBundle.load(
          locationConfigService.alternateSampleImagePath,
        );
        final bytes = byteData.buffer.asUint8List();
        base64Image = base64Encode(bytes);
        effectiveUseSample = false;
      } catch (e) {
        print('NavigationBloc: Alternate image loading failed: $e');
      }
    } else if (event.imagePath != null &&
        event.imagePath!.isNotEmpty &&
        !useSampleImage) {
      try {
        final imageFile = File(event.imagePath!);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          base64Image = base64Encode(imageBytes);
        }
      } catch (e) {
        // If image encoding fails, continue with empty string
        print('NavigationBloc: Image encoding failed: $e');
      }
    }

    // Step 3: Get route
    emit(const NavigationLoading(message: 'Calculating route...'));

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
        userPickedCoordinates: event.userPickedCoordinates,
      ),
    );

    await routeResult.fold(
      (failure) async => emit(NavigationError(failure.message)),
      (route) async {
        // Use the actual floor name from the route steps to ensure exact string matching in UI
        final actualStartingFloor = route.multiFloorSteps.isNotEmpty
            ? route.multiFloorSteps.first.floor
            : floor;

        // Get cached destinations for POI display — load for all route floors.
        // For floors not yet cached, fetch from the API so POIs always show.
        List<DestinationEntity> destinations = [];
        final Map<String, List<DestinationEntity>> destinationsByFloor = {};

        // Normalise floor string for comparison: "17_floor" → "17"
        String normaliseFloor(String f) =>
            f.replaceAll('_floor', '').replaceAll('_', '').trim().toLowerCase();

        // Helper: fetch destinations for a floor (cache-first), filtering the
        // API response so only POIs belonging to that floor are returned.
        // The multifloor API returns ALL floors' POIs in one call; we
        // group them and cache each floor's slice individually.
        Future<List<DestinationEntity>> fetchDestsForFloor(
          String floorKey,
        ) async {
          // 1. Try cache (already filtered when stored)
          final cached = destinationsCacheService.getCachedDestinations(
            place: place,
            building: building,
            floor: floorKey,
            multiFloor: locationConfigService.multiFloorNavigation,
          );
          if (cached != null && cached.isNotEmpty) return cached;

          // 2. Fetch from API
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

          // Group by each destination's own floor field so we can cache and
          // return only the subset that belongs to the requested floor.
          final Map<String, List<DestinationEntity>> grouped = {};
          for (final d in allDests) {
            final normDest = d.floor != null
                ? normaliseFloor(d.floor!)
                : normaliseFloor(floorKey);
            grouped.putIfAbsent(normDest, () => []).add(d);
          }

          // Cache each floor's slice under the matching route floor key
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

          // Return only the slice for the requested floor
          return grouped[normaliseFloor(floorKey)] ?? [];
        }

        // Load destinations for every floor in parallel
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

        // Save locally
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

        // For multi-floor routes, load floor plans for every floor in parallel
        final Map<String, String> floorPlansByFloor = {};
        if (floorPlanBase64 != null && floorPlanBase64!.isNotEmpty) {
          // Note: if the requested floor and actual floor differ,
          // we might need to fetch the plan for the actual floor, but
          // usually they match or the requested plan is for the first step.
          floorPlansByFloor[actualStartingFloor] = floorPlanBase64!;
        }

        if (route.multiFloorSteps.length > 1) {
          final otherFloors = route.multiFloorSteps
              .map((s) => s.floor)
              .where((f) => f != actualStartingFloor)
              .toSet()
              .toList();

          await Future.wait(
            otherFloors.map((floorKey) async {
              // Check cache first
              if (floorPlanCacheService.hasCachedFloorPlan(
                place: place,
                building: building,
                floor: floorKey,
              )) {
                final cached = floorPlanCacheService.getCachedFloorPlanBase64(
                  place: place,
                  building: building,
                  floor: floorKey,
                );
                if (cached != null && cached.isNotEmpty) {
                  floorPlansByFloor[floorKey] = cached;
                  return;
                }
              }
              // Fetch from API
              final result = await getFloorPlanUseCase(
                GetFloorPlanParams(
                  building: building,
                  floor: floorKey,
                  place: place,
                ),
              );
              await result.fold((_) async {}, (plan) async {
                if (plan.base64Image.isNotEmpty) {
                  floorPlansByFloor[floorKey] = plan.base64Image;
                  await floorPlanCacheService.cacheFloorPlan(
                    place: place,
                    building: building,
                    floor: floorKey,
                    base64Image: plan.base64Image,
                  );
                }
              });
            }),
          );
        }

        emit(
          NavigationReady(
            currentLocation: route.origin.copyWith(floor: actualStartingFloor),
            route: route,
            floorPlanBase64: floorPlanBase64,
            destinations: destinations,
            floorPlansByFloor: floorPlansByFloor,
            destinationsByFloor: destinationsByFloor,
          ),
        );
      },
    );
  }
}
