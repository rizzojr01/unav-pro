import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';
import '../../data/datasources/spatial_audio_channel_contract.dart';
import '../../domain/entities/ar_pose.dart';
import '../../domain/entities/localized_pose.dart';
import '../../domain/repositories/ar_pose_repository.dart';
import '../../domain/services/ar_pose_transformer.dart';
import '../../domain/services/path_tracking_service.dart';
import '../../domain/services/spatial_audio_service.dart';
import 'ar_navigation_event.dart';
import 'ar_navigation_state.dart';

class ArNavigationBloc extends Bloc<ArNavigationEvent, ArNavigationState> {
  final ArPoseRepository _poseRepository;
  final ArPoseTransformer _poseTransformer;
  final PathTrackingService _pathTracker;
  final SpatialAudioService _audioService;

  StreamSubscription<ArPose>? _poseSubscription;
  ArPose? _originArPose;
  LocalizedPose? _referencePose;
  double? _metersPerPixel;
  RouteEntity? _route;
  ArTrackingState _lastState = ArTrackingState.idle;

  ArNavigationBloc({
    required ArPoseRepository poseRepository,
    required ArPoseTransformer poseTransformer,
    required PathTrackingService pathTracker,
    required SpatialAudioService audioService,
  }) : _poseRepository = poseRepository,
       _poseTransformer = poseTransformer,
       _pathTracker = pathTracker,
       _audioService = audioService,
       super(const ArNavigationInitial()) {
    on<StartArTrackingEvent>(_onStartTracking);
    on<StopArTrackingEvent>(_onStopTracking);
    on<ArPoseUpdatedEvent>(_onPoseUpdated);
  }

  Future<void> _onStartTracking(
    StartArTrackingEvent event,
    Emitter<ArNavigationState> emit,
  ) async {
    _referencePose = event.referencePose;
    _metersPerPixel = event.metersPerPixel;
    _route = event.route;
    _originArPose = null;

    await _poseSubscription?.cancel();
    _poseSubscription = _poseRepository.watchPose().listen((pose) {
      add(ArPoseUpdatedEvent(pose));
    });

    await _poseRepository.start();
    emit(
      const ArNavigationTracking(
        state: ArTrackingState.localizing,
        trackedPath: [],
        nextWaypointIndex: 0,
        remainingDistancePx: 0,
        distanceToNextWaypointPx: 0,
      ),
    );
  }

  Future<void> _onStopTracking(
    StopArTrackingEvent event,
    Emitter<ArNavigationState> emit,
  ) async {
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    await _poseRepository.stop();
    emit(const ArNavigationInitial());
  }

  void _onPoseUpdated(
    ArPoseUpdatedEvent event,
    Emitter<ArNavigationState> emit,
  ) {
    if (_referencePose == null || _metersPerPixel == null || _route == null) {
      return;
    }

    // Anchor the world origin to the first real AR pose from ARKit.
    // We use the raw pose as-is — no heading override.
    //
    // Why: ARKit heading (yawDegrees in AppDelegate) is 0=East CCW, relative
    // to wherever the camera faced at session start. It is NOT in the same
    // coordinate system as capturedSensorHeading (compass, 0=North CW).
    // Overriding with capturedSensorHeading mixes two incompatible systems
    // and produces a wrong sumHeadingDeg in ArPoseTransformer.
    //
    // The correct alignment is handled by pixelToAr using the static
    // (270 - backendAng) rotation, which maps the floorplan to ARKit world
    // space assuming the camera faces backendAng at session start.
    _originArPose ??= event.pose;

    // Use a realistic fallback if metersPerPixel is 1.0 (unscaled)
    final effectiveMpp = (_metersPerPixel == 1.0) ? 0.05 : _metersPerPixel!;

    // ArPoseTransformer now produces correctly-aligned FP coordinates and
    // heading directly from ARKit's gravityAndHeading world frame.
    // No additional delta correction is needed — the session's compass
    // alignment handles it at the native layer.
    final localizedPose = _poseTransformer.transform(
      currentArPose: event.pose,
      originArPose: _originArPose!,
      referenceFloorplanPose: _referencePose!,
      metersPerPixel: effectiveMpp,
    );

    final previousWaypointIndex = state is ArNavigationTracking
        ? (state as ArNavigationTracking).nextWaypointIndex
        : 0;

    final update = _pathTracker.update(
      pose: localizedPose,
      anchor: _referencePose,
      route: _route!,
      metersPerPixel: effectiveMpp,
      previousWaypointIndex: previousWaypointIndex,
    );

    _handleArOverlay(update, localizedPose);
    _handleAudioGuidance(update);

    final guidanceMessage = _buildGuidanceMessage(update, localizedPose);

    emit(
      ArNavigationTracking(
        currentPose: localizedPose,
        state: update.state,
        trackedPath: update.trackedPath,
        nextWaypointIndex: update.nextWaypointIndex,
        remainingDistancePx: update.remainingDistancePx,
        distanceToNextWaypointPx: update.distanceToNextWaypointPx,
        guidanceMessage: guidanceMessage,
      ),
    );
  }

  String? _buildGuidanceMessage(ArTrackingUpdate update, LocalizedPose pose) {
    if (update.state == ArTrackingState.offRoute) return null;
    if (update.state == ArTrackingState.arrived) {
      return 'Arrived at the destination.';
    }

    if (_route == null || _route!.steps.isEmpty) return null;

    final routePoints = _route!.steps
        .map((s) => Offset(s.from.x, s.from.y))
        .toList();
    routePoints.add(Offset(_route!.steps.last.to.x, _route!.steps.last.to.y));

    final waypoint =
        routePoints[update.nextWaypointIndex.clamp(0, routePoints.length - 1)];

    // Bearing in floorplan space (0=East, 90=South [Clockwise])
    final mathDx = waypoint.dx - pose.x;
    final mathDy = waypoint.dy - pose.y;

    // targetAngle is the angle (0=East, 90=South) we want the user to face
    // On floorplan: dy < 0 is North (270°), dx > 0 is East (0°)
    final targetAngle = _normalizeDegrees(
      math.atan2(mathDy, mathDx) * 180.0 / math.pi,
    );

    // pose.heading is the corrected heading (0=East, 90=South [Clockwise])
    // However, the floorplan math (atan2) returns 0=East, -90=North
    // Our heading system is 0=East, 90=South, 270=North.
    // Let's verify if TargetAngle needs to be converted to Clockwise 0-360.
    // math.atan2 returns (-pi, pi].
    // If dy=-1, dx=0 (North), atan2=-pi/2 (-90°). _normalizeDegrees(-90) = 270°. Correct.

    // pose.heading is now in floorplan space (0=East, 90=South CW), matching
    // targetAngle from atan2. No offset needed.
    final poseHeadingForGuidance = pose.heading;

    final headingDelta = _signedHeadingDeltaDeg(
      poseHeadingForGuidance,
      targetAngle,
    );

    final angle = headingDelta.abs().round();

    final mpp = (_metersPerPixel == 1.0) ? 0.05 : (_metersPerPixel ?? 0.05);
    final distanceMeters = update.distanceToNextWaypointPx * mpp;

    final distanceText = _formatDistance(distanceMeters);

    if (angle <= 25) {
      return 'Go straight for $distanceText.';
    }

    final dir = headingDelta > 0 ? 'right' : 'left';
    return 'Turn $dir $angle°, then go $distanceText.';
  }

  String _formatDistance(double distanceMeters) {
    // TODO: Get unit from settings
    const unit = 'meter';
    if (unit == 'feet') {
      final feet = distanceMeters * 3.28084;
      return feet >= 10
          ? '${feet.round()} feet'
          : '${feet.toStringAsFixed(1)} feet';
    }
    return distanceMeters >= 10
        ? '${distanceMeters.round()} m'
        : '${distanceMeters.toStringAsFixed(1)} m';
  }

  double _signedHeadingDeltaDeg(double currentDeg, double targetDeg) {
    var delta = (targetDeg - currentDeg + 540.0) % 360.0 - 180.0;
    if (delta < -180.0) {
      delta += 360.0;
    }
    return delta;
  }

  double _normalizeDegrees(double value) {
    var normalized = value % 360.0;
    if (normalized < 0) {
      normalized += 360.0;
    }
    return normalized;
  }

  void _handleAudioGuidance(ArTrackingUpdate update) {
    if (update.state != _lastState) {
      if (update.state == ArTrackingState.arrived) {
        _audioService.playCue(SpatialAudioChannelContract.cueTypeArrived);
        HapticFeedback.heavyImpact();
        Timer(const Duration(milliseconds: 300), () => HapticFeedback.heavyImpact());
      } else if (update.state == ArTrackingState.offRoute) {
        _audioService.primeOffRouteLoop();
        HapticFeedback.vibrate();
      } else if (_lastState == ArTrackingState.offRoute &&
          update.state == ArTrackingState.tracking) {
        _audioService.stopOffRouteAlert();
        HapticFeedback.lightImpact();
      } else if (update.nextWaypointIndex > 0) {
        // Just passed a waypoint
        HapticFeedback.mediumImpact();
      }
      _lastState = update.state;
    }

    if (update.state == ArTrackingState.offRoute) {
      // Calculate heading error for spatial audio
      final mpp = (_metersPerPixel == 1.0) ? 0.05 : (_metersPerPixel ?? 0.05);
      
      // The relative angle to the path helps the native side play audio from the correct direction
      // For now, we use a simple 'center' side but provide the distance
      _audioService.updateOffRouteAlert(
        side: 'center', 
        severity: update.offRouteSeverity,
        headingErrorDeg: 0, 
        relativeAngleDeg: 0,
        sourceDistanceMeters: update.distanceToPathPx * mpp,
        distanceToWaypointMeters: update.distanceToNextWaypointPx * mpp,
      );
      
      // Periodic haptic feedback for off-route based on severity
      if (DateTime.now().millisecond % 1000 < 100) {
        if (update.offRouteSeverity > 0.5) {
          HapticFeedback.selectionClick();
        }
      }
    }
  }

  void _handleArOverlay(ArTrackingUpdate update, LocalizedPose currentPose) {
    if (_route == null || _originArPose == null || _referencePose == null) {
      return;
    }

    final mpp = (_metersPerPixel == 1.0) ? 0.05 : _metersPerPixel!;
    final reference = _referencePose!;
    final origin = _originArPose!;

    // Mirroring ar_temp's _floorplanPointToArWorld:
    //   sumHeadingDeg rotates between the floorplan math-plane and AR world.
    final captureHeading = _normalizeDegrees(origin.heading);
    final sumHeadingDeg = _normalizeDegrees(reference.heading + captureHeading);
    final sumHeadingRad = sumHeadingDeg * math.pi / 180.0;

    // Origin pose in math-plane (East, North).
    final originWorldX = origin.worldX ?? origin.x;
    final originWorldZ = origin.worldZ ?? -origin.y;
    final originMathX = originWorldX;
    final originMathY = -originWorldZ; // North

    // Reference in math-plane (flip Y from image).
    final refMathX = reference.x;
    final refMathY = -reference.y;

    // Floor Y: 1.35 m below camera (ar_temp constant _overlayFloorOffsetMeters).
    final cameraWorldY = origin.worldY ?? origin.z;
    final floorWorldY = cameraWorldY - 1.35;

    // Converts a floorplan image point to ARKit world-space [worldX, worldY, worldZ].
    List<double> floorplanToArWorld(double px, double py) {
      // Image → math plane
      final mathX = px;
      final mathY = -py;

      final deltaMetersX = (mathX - refMathX) * mpp;
      final deltaMetersY = (mathY - refMathY) * mpp;

      // CCW rotation by sumHeadingRad (inverse of _transformTrackedPose CW rotation)
      final arDeltaX =
          deltaMetersX * math.cos(sumHeadingRad) - deltaMetersY * math.sin(sumHeadingRad);
      final arDeltaY =
          deltaMetersX * math.sin(sumHeadingRad) + deltaMetersY * math.cos(sumHeadingRad);

      final targetMathX = originMathX + arDeltaX;
      final targetMathY = originMathY + arDeltaY;

      // Math plane (East, North) → AR world: worldX = East, worldZ = −North
      final worldX = targetMathX;
      final worldZ = -targetMathY;

      return [worldX, floorWorldY, worldZ];
    }

    final routePoints = _route!.steps
        .map((s) => Offset(s.from.x, s.from.y))
        .toList();
    routePoints.add(Offset(_route!.steps.last.to.x, _route!.steps.last.to.y));

    final allPathAr =
        routePoints.map((p) => floorplanToArWorld(p.dx, p.dy)).toList();

    final nextWaypoint = routePoints[update.nextWaypointIndex];
    final activePathAr = [
      floorplanToArWorld(currentPose.x, currentPose.y),
      ...routePoints
          .skip(update.nextWaypointIndex)
          .map((p) => floorplanToArWorld(p.dx, p.dy)),
    ];

    _poseRepository.updateOverlay(
      pathPoints: allPathAr,
      activePathPoints: activePathAr,
      futurePathPoints: [],
      nextWaypoint: floorplanToArWorld(nextWaypoint.dx, nextWaypoint.dy),
      destination: floorplanToArWorld(routePoints.last.dx, routePoints.last.dy),
    );
  }

  @override
  Future<void> close() {
    _poseSubscription?.cancel();
    _poseRepository.stop();
    return super.close();
  }
}
