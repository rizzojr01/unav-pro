import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/services/destinations_cache_service.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/services/device_id_service.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/floor_plan_entity.dart';
import '../../domain/entities/localization_request_entity.dart';
import '../../domain/entities/user_position_entity.dart';
import '../../domain/usecases/get_floor_plan_usecase.dart';
import '../../domain/usecases/localize_user_usecase.dart';
import '../../domain/usecases/get_destinations_usecase.dart';
import 'locate_me_event.dart';
import 'locate_me_state.dart';

class LocateMeBloc extends Bloc<LocateMeEvent, LocateMeState> {
  final GetFloorPlanUseCase getFloorPlanUseCase;
  final LocalizeUserUseCase localizeUserUseCase;
  final GetDestinationsUseCase getDestinationsUseCase;
  final LocationConfigService locationConfigService;
  final FloorPlanCacheService floorPlanCacheService;
  final DestinationsCacheService destinationsCacheService;
  final DeviceIdService deviceIdService;

  // Get configuration from service
  String get _building => locationConfigService.building;
  String get _floor => locationConfigService.floor;
  String get _place => locationConfigService.place;

  LocateMeBloc({
    required this.getFloorPlanUseCase,
    required this.localizeUserUseCase,
    required this.getDestinationsUseCase,
    required this.locationConfigService,
    required this.floorPlanCacheService,
    required this.destinationsCacheService,
    required this.deviceIdService,
  }) : super(const LocateMeInitial()) {
    on<StartLocalizationEvent>(_onStartLocalization);
    on<LocateMeCapturePhotoEvent>(_onCapturePhoto);
    on<StartLocalizationWithSampleEvent>(_onStartLocalizationWithSample);
    on<StartLocalizationWithCoordinatesEvent>(
      _onStartLocalizationWithCoordinates,
    );
    on<SelectDestinationEvent>(_onSelectDestination);
    on<ClearSelectedDestinationEvent>(_onClearSelectedDestination);
    on<ResetLocateMeEvent>(_onReset);
  }

  void _onCapturePhoto(
    LocateMeCapturePhotoEvent event,
    Emitter<LocateMeState> emit,
  ) {
    emit(
      LocateMePhotoCaptured(
        event.capturedImagePath,
        floor: event.floor,
        heading: event.heading,
      ),
    );
  }

  Future<void> _onStartLocalization(
    StartLocalizationEvent event,
    Emitter<LocateMeState> emit,
  ) async {
    emit(const LocateMeLoading(message: 'Analyzing your location...'));

    final useSampleImage = locationConfigService.useSampleImage;
    final useAlternate = locationConfigService.useAlternateSampleImage;

    try {
      String base64Image = '';
      bool effectiveUseSample = useSampleImage;

      if (useAlternate) {
        final byteData = await rootBundle.load(
          locationConfigService.alternateSampleImagePath,
        );
        final bytes = byteData.buffer.asUint8List();
        base64Image = base64Encode(bytes);
        effectiveUseSample = false;
      } else if (event.capturedImagePath.isNotEmpty && !useSampleImage) {
        final imageFile = File(event.capturedImagePath);
        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          base64Image = base64Encode(imageBytes);
        }
      }

      await _performLocalization(
        emit,
        base64Image,
        useSampleImage: effectiveUseSample,
        floor: event.floor,
        heading: event.heading,
      );
    } catch (e) {
      emit(LocateMeError('Failed to process image: ${e.toString()}'));
    }
  }

  Future<void> _onStartLocalizationWithSample(
    StartLocalizationWithSampleEvent event,
    Emitter<LocateMeState> emit,
  ) async {
    emit(const LocateMeLoading(message: 'Analyzing your location...'));

    // Use empty string for base64 image when using sample
    await _performLocalization(emit, '', useSampleImage: true);
  }

  Future<void> _onStartLocalizationWithCoordinates(
    StartLocalizationWithCoordinatesEvent event,
    Emitter<LocateMeState> emit,
  ) async {
    emit(const LocateMeLoading(message: 'Loading floor plan...'));

    try {
      // Skip image processing, use manual coordinates directly
      await _performLocalizationWithManualCoordinates(
        emit,
        event.x,
        event.y,
        floor: event.floor,
      );
    } catch (e) {
      emit(LocateMeError('Failed to load floor plan: ${e.toString()}'));
    }
  }

  Future<void> _performLocalization(
    Emitter<LocateMeState> emit,
    String base64Image, {
    bool useSampleImage = false,
    String? floor,
    double? heading,
  }) async {
    // Step 1: Get floor plan (with caching)
    emit(const LocateMeLoading(message: 'Loading floor plan...'));

    final effectiveFloor = floor ?? _floor;

    FloorPlanEntity? floorPlan;
    String? floorPlanError;

    // Check cache first
    if (floorPlanCacheService.hasCachedFloorPlan(
      place: _place,
      building: _building,
      floor: effectiveFloor,
    )) {
      // Use cached floor plan
      final cachedBase64 = floorPlanCacheService.getCachedFloorPlanBase64(
        place: _place,
        building: _building,
        floor: effectiveFloor,
      );
      if (cachedBase64 != null && cachedBase64.isNotEmpty) {
        floorPlan = FloorPlanEntity(
          base64Image: cachedBase64,
          filename: '${_building}_$effectiveFloor.png',
        );
      }
    }

    // If no cache, fetch from API
    if (floorPlan == null) {
      final floorPlanResult = await getFloorPlanUseCase(
        GetFloorPlanParams(
          building: _building,
          floor: effectiveFloor,
          place: _place,
        ),
      );

      await floorPlanResult.fold(
        (failure) async {
          floorPlanError = failure.message;
        },
        (result) async {
          floorPlan = result;
          // Cache the floor plan for future use
          if (result.base64Image.isNotEmpty) {
            await floorPlanCacheService.cacheFloorPlan(
              place: _place,
              building: _building,
              floor: effectiveFloor,
              base64Image: result.base64Image,
            );
          }
        },
      );
    }

    // If floor plan failed and no cache, show error
    if (floorPlan == null) {
      emit(
        LocateMeError(
          floorPlanError ?? 'Failed to load floor plan. Please try again.',
        ),
      );
      return;
    }

    // Step 2: Localize user
    emit(const LocateMeLoading(message: 'Determining your position...'));
    // Use the stable device ID as session identifier so the backend always
    // sees the same user/device across every request from this device.
    final sessionId = deviceIdService.getDeviceId();

    final localizationRequest = LocalizationRequestEntity(
      base64Image: base64Image,
      building: _building,
      floor: effectiveFloor,
      place: _place,
      sessionId: sessionId,
      unavMultifloor: locationConfigService.multiFloorNavigation,
      useSampleImage: useSampleImage,
      relocalize: true,
      saveframe: locationConfigService.saveFrame,
      shortenVlmResponse: true,
      speakVlmFirst: true,
      useVlm: false,
      heading: heading,
      imageCompression: ImageCompressionEntity(
        enableCompression: locationConfigService.enableCompression,
        maxHeight: locationConfigService.maxHeight,
        maxWidth: locationConfigService.maxWidth,
        quality: locationConfigService.imageQuality,
      ),
    );

    final positionResult = await localizeUserUseCase(localizationRequest);

    await positionResult.fold(
      (failure) async {
        emit(LocateMeError(failure.message));
      },
      (userPosition) async {
        // Step 3: Get destinations (with caching)
        emit(const LocateMeLoading(message: 'Loading places of interest...'));

        List<DestinationEntity>? destinations;
        String? destinationsError;

        // Check cache first
        if (destinationsCacheService.hasCachedDestinations(
          place: _place,
          building: _building,
          floor: effectiveFloor,
          multiFloor: locationConfigService.multiFloorNavigation,
        )) {
          // Use cached destinations
          destinations = destinationsCacheService.getCachedDestinations(
            place: _place,
            building: _building,
            floor: effectiveFloor,
            multiFloor: locationConfigService.multiFloorNavigation,
          );
        }

        // If no cache, fetch from API
        if (destinations == null || destinations.isEmpty) {
          final destinationsResult = await getDestinationsUseCase(
            GetDestinationsParams(
              building: _building,
              floor: effectiveFloor,
              place: _place,
              includeCoordinates: true,
            ),
          );

          await destinationsResult.fold(
            (failure) async {
              destinationsError = failure.message;
            },
            (result) async {
              destinations = result;
              // Cache the destinations for future use
              if (result.isNotEmpty) {
                await destinationsCacheService.cacheDestinations(
                  place: _place,
                  building: _building,
                  floor: effectiveFloor,
                  multiFloor: locationConfigService.multiFloorNavigation,
                  destinations: result,
                );
              }
            },
          );
        }

        if (destinations == null) {
          emit(
            LocateMeError(
              destinationsError ??
                  'Failed to load destinations. Please try again.',
            ),
          );
          return;
        }

        emit(
          LocateMeReady(
            floorPlan: floorPlan!,
            userPosition: userPosition.copyWith(floor: effectiveFloor),
            destinations: destinations!,
            floor: effectiveFloor,
          ),
        );
      },
    );
  }

  Future<void> _performLocalizationWithManualCoordinates(
    Emitter<LocateMeState> emit,
    double x,
    double y, {
    String? floor,
  }) async {
    // Step 1: Get floor plan (with caching)
    emit(const LocateMeLoading(message: 'Loading floor plan...'));

    final effectiveFloor = floor ?? _floor;

    FloorPlanEntity? floorPlan;
    String? floorPlanError;

    // Check cache first
    if (floorPlanCacheService.hasCachedFloorPlan(
      place: _place,
      building: _building,
      floor: effectiveFloor,
    )) {
      // Use cached floor plan
      final cachedBase64 = floorPlanCacheService.getCachedFloorPlanBase64(
        place: _place,
        building: _building,
        floor: effectiveFloor,
      );
      if (cachedBase64 != null && cachedBase64.isNotEmpty) {
        floorPlan = FloorPlanEntity(
          base64Image: cachedBase64,
          filename: '${_building}_$effectiveFloor.png',
        );
      }
    }

    // If no cache, fetch from API
    if (floorPlan == null) {
      final floorPlanResult = await getFloorPlanUseCase(
        GetFloorPlanParams(
          building: _building,
          floor: effectiveFloor,
          place: _place,
        ),
      );

      await floorPlanResult.fold(
        (failure) async {
          floorPlanError = failure.message;
        },
        (result) async {
          floorPlan = result;
          // Cache the floor plan for future use
          if (result.base64Image.isNotEmpty) {
            await floorPlanCacheService.cacheFloorPlan(
              place: _place,
              building: _building,
              floor: effectiveFloor,
              base64Image: result.base64Image,
            );
          }
        },
      );
    }

    // If floor plan failed and no cache, show error
    if (floorPlan == null) {
      emit(
        LocateMeError(
          floorPlanError ?? 'Failed to load floor plan. Please try again.',
        ),
      );
      return;
    }

    // Step 2: Create user position from manual coordinates
    emit(const LocateMeLoading(message: 'Setting your position...'));
    final userPosition = UserPositionEntity(
      x: x,
      y: y,
      angle: 0.0, // Default angle for manual selection
    );

    // Step 3: Get destinations (with caching)
    emit(const LocateMeLoading(message: 'Loading places of interest...'));

    List<DestinationEntity>? destinations;
    String? destinationsError;

    // Check cache first
    if (destinationsCacheService.hasCachedDestinations(
      place: _place,
      building: _building,
      floor: effectiveFloor,
      multiFloor: locationConfigService.multiFloorNavigation,
    )) {
      // Use cached destinations
      destinations = destinationsCacheService.getCachedDestinations(
        place: _place,
        building: _building,
        floor: effectiveFloor,
        multiFloor: locationConfigService.multiFloorNavigation,
      );
    }

    // If no cache, fetch from API
    if (destinations == null || destinations.isEmpty) {
      final destinationsResult = await getDestinationsUseCase(
        GetDestinationsParams(
          building: _building,
          floor: effectiveFloor,
          place: _place,
          includeCoordinates: true,
        ),
      );

      await destinationsResult.fold(
        (failure) async {
          destinationsError = failure.message;
        },
        (result) async {
          destinations = result;
          // Cache the destinations for future use
          if (result.isNotEmpty) {
            await destinationsCacheService.cacheDestinations(
              place: _place,
              building: _building,
              floor: effectiveFloor,
              multiFloor: locationConfigService.multiFloorNavigation,
              destinations: result,
            );
          }
        },
      );
    }

    if (destinations == null) {
      emit(
        LocateMeError(
          destinationsError ?? 'Failed to load destinations. Please try again.',
        ),
      );
      return;
    }

    emit(
      LocateMeReady(
        floorPlan: floorPlan!,
        userPosition: userPosition.copyWith(floor: effectiveFloor),
        destinations: destinations!,
        isManualLocalization: true,
        floor: effectiveFloor,
      ),
    );
  }

  void _onSelectDestination(
    SelectDestinationEvent event,
    Emitter<LocateMeState> emit,
  ) {
    if (state is LocateMeReady) {
      final currentState = state as LocateMeReady;
      emit(currentState.copyWith(selectedDestination: event.destination));
    }
  }

  void _onClearSelectedDestination(
    ClearSelectedDestinationEvent event,
    Emitter<LocateMeState> emit,
  ) {
    if (state is LocateMeReady) {
      final currentState = state as LocateMeReady;
      emit(currentState.copyWith(clearSelectedDestination: true));
    }
  }

  void _onReset(ResetLocateMeEvent event, Emitter<LocateMeState> emit) {
    emit(const LocateMeInitial());
  }
}
