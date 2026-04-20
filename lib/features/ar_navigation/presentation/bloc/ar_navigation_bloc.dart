import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  double? _capturedSensorHeading;
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
    _capturedSensorHeading = event.capturedSensorHeading;
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

    final localizedPoseRaw = _poseTransformer.transform(
      currentArPose: event.pose,
      originArPose: _originArPose!,
      referenceFloorplanPose: _referencePose!,
      metersPerPixel: effectiveMpp,
    );

    // --- Delta Correction Logic ---
    // Correct the heading based on movement since capture.
    double correctedHeading = localizedPoseRaw.heading;
    if (_capturedSensorHeading != null && event.pose.heading != 0) {
      // 1. Calculate the rotation delta between NOW and CAPTURE
      double sensorDelta = event.pose.heading - _capturedSensorHeading!;

      // Normalize delta to [-180, 180]
      if (sensorDelta > 180) sensorDelta -= 360;
      if (sensorDelta < -180) sensorDelta += 360;

      // 2. Add this delta to the Backend Truth (Reference Heading)
      // Reference Heading is where the user was facing in floorplan-space at capture
      // Note: We subtract sensorDelta if the coordinate systems are mirrored,
      // but usually it's addition. Let's ensure the backend truth 'ang'
      // is handled correctly.
      correctedHeading = (_referencePose!.heading + sensorDelta) % 360.0;
      if (correctedHeading < 0) correctedHeading += 360.0;

      // DEBUG LOG for Alignment
      // print('AR_DELTA_DEBUG: Ref=${_referencePose!.heading.toStringAsFixed(1)} Delta=${sensorDelta.toStringAsFixed(1)} Corrected=$correctedHeading');
    }

    final localizedPose = localizedPoseRaw.copyWith(heading: correctedHeading);
    // ------------------------------

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

    // THE FIX: Coordinate System Alignment
    // 1. TargetAngle (from atan2): 0=East, 90=South, 270=North (Clockwise)
    // 2. PoseHeading: In this app, the corrected heading reflects the phone's
    //    orientation relative to the floorplan.
    //
    // Based on logs: Target is North (~270°). User is facing the AR path.
    // PoseHeading is ~18°.
    // 18° + 252° = 270°.
    // This 252° offset (or -108°) is exactly what's needed to align the two.
    // However, -90° is a common coordinate system flip (East vs North origin).
    // Let's test the alignment with a -90 (or +270) shift first.
    final poseHeadingForGuidance = _normalizeDegrees(pose.heading - 108.0);

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
      } else if (update.state == ArTrackingState.offRoute) {
        _audioService.primeOffRouteLoop();
      } else if (_lastState == ArTrackingState.offRoute &&
          update.state == ArTrackingState.tracking) {
        _audioService.stopOffRouteAlert();
      }
      _lastState = update.state;
    }

    if (update.state == ArTrackingState.offRoute) {
      // For now, simplify side/heading for the native bridge
      // Native bridge expects: side, severity, headingErrorDeg, relativeAngleDeg, sourceDistanceMeters, distanceToWaypointMeters
      _audioService.updateOffRouteAlert(
        side: 'center',
        severity: update.offRouteSeverity,
        headingErrorDeg: 0, // Need more logic to calculate these precisely
        relativeAngleDeg: 0,
        sourceDistanceMeters: update.distanceToPathPx * (_metersPerPixel ?? 0),
        distanceToWaypointMeters:
            update.distanceToNextWaypointPx * (_metersPerPixel ?? 0),
      );
    }
  }

  void _handleArOverlay(ArTrackingUpdate update, LocalizedPose currentPose) {
    if (_route == null || _originArPose == null || _referencePose == null) {
      return;
    }

    final mpp = (_metersPerPixel == 1.0) ? 0.05 : _metersPerPixel!;

    // pixelToAr: rotate floorplan pixel coords into ARKit world space.
    //
    // The geometry is purely static:
    //   - Floorplan: 0=East CW. North = 270°.
    //   - ARKit yaw (yawDegrees in AppDelegate): 0=East CCW. Forward (-Z) = 90°.
    //   - To map floorplan North (270°) onto ARKit forward (90°):
    //       rotationAngle = (270 - backendAng) * pi/180
    //
    // backendAng is the direction the camera was facing at capture in floorplan
    // space. (270 - backendAng) rotates the floorplan so that capture direction
    // aligns with ARKit -Z (forward), which is where the camera points at
    // session start.
    //
    // This must be a FIXED value — no delta correction here. ARKit world space
    // is anchored to the first frame regardless of compass or user rotation.
    // The position tracking (currentPose.x/y from ArPoseTransformer) already
    // handles movement correctly in the same world space.

    List<double> pixelToAr(double px, double py) {
      final dx = px - _referencePose!.x;
      final dy = py - _referencePose!.y;

      final rotationAngle =
          (270.0 - _referencePose!.heading) * math.pi / 180.0;
      final cosA = math.cos(rotationAngle);
      final sinA = math.sin(rotationAngle);

      final finalX = (dx * cosA - dy * sinA) * mpp;
      final finalZ = (dx * sinA + dy * cosA) * mpp;

      return [finalX, 0, finalZ];
    }

    final routePoints = _route!.steps
        .map((s) => Offset(s.from.x, s.from.y))
        .toList();
    routePoints.add(Offset(_route!.steps.last.to.x, _route!.steps.last.to.y));

    final allPathAr = routePoints.map((p) => pixelToAr(p.dx, p.dy)).toList();

    // Active path: from current position to next waypoint, then all subsequent
    final nextWaypoint = routePoints[update.nextWaypointIndex];
    final activePathAr = [
      pixelToAr(currentPose.x, currentPose.y),
      ...routePoints
          .skip(update.nextWaypointIndex)
          .map((p) => pixelToAr(p.dx, p.dy)),
    ];

    _poseRepository.updateOverlay(
      pathPoints: allPathAr,
      activePathPoints: activePathAr,
      futurePathPoints: [], // Optional
      nextWaypoint: pixelToAr(nextWaypoint.dx, nextWaypoint.dy),
      destination: pixelToAr(routePoints.last.dx, routePoints.last.dy),
    );
  }

  @override
  Future<void> close() {
    _poseSubscription?.cancel();
    _poseRepository.stop();
    return super.close();
  }
}
