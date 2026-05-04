import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';
import '../../domain/entities/ar_pose.dart';
import '../../domain/entities/localized_pose.dart';
import '../../domain/models/audio_cue_direction.dart';
import '../../domain/models/guidance_event_type.dart';
import '../../domain/repositories/ar_pose_repository.dart';
import '../../domain/services/ar_pose_transformer.dart';
import '../../domain/services/guidance_sound_service.dart';
import '../../domain/services/path_tracking_service.dart';
import 'ar_navigation_event.dart';
import 'ar_navigation_state.dart';

class ArNavigationBloc extends Bloc<ArNavigationEvent, ArNavigationState> {
  final ArPoseRepository _poseRepository;
  final ArPoseTransformer _poseTransformer;
  final PathTrackingService _pathTracker;
  final GuidanceSoundService _soundService;

  StreamSubscription<ArPose>? _poseSubscription;
  ArPose? _originArPose;
  LocalizedPose? _referencePose;
  double? _metersPerPixel;
  RouteEntity? _route;
  ArTrackingState _lastState = ArTrackingState.idle;
  int _lastWaypointIndex = 0;
  // Compass delta: how much the user rotated between image capture and route plot.
  // Added to sumHeadingDeg so the AR path aligns correctly even if user turned during loading.
  double _compassDeltaDeg = 0.0;

  ArNavigationBloc({
    required ArPoseRepository poseRepository,
    required ArPoseTransformer poseTransformer,
    required PathTrackingService pathTracker,
    required GuidanceSoundService soundService,
  }) : _poseRepository = poseRepository,
       _poseTransformer = poseTransformer,
       _pathTracker = pathTracker,
       _soundService = soundService,
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
    _lastState = ArTrackingState.idle;
    _lastWaypointIndex = 0;

    // Compute one-time compass delta: rotation between image capture and route plot.
    final captured = event.capturedSensorHeading;
    final plot = event.plotSensorHeading;
    _compassDeltaDeg = (captured != null && plot != null)
        ? _shortestArc(plot - captured)
        : 0.0;

    await _soundService.init();

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
    _soundService.updateDirectionalGuidance(
      isActive: false,
      severity: 0,
      direction: AudioCueDirection.center,
      headingErrorDeg: 180,
      relativeAngleDeg: 0,
      sourceDistanceMeters: 6,
      distanceToWaypointMeters: 6,
    );
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
    _handleAudioGuidance(update, localizedPose);

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

    final mathDx = waypoint.dx - pose.x;
    final mathDy = waypoint.dy - pose.y;

    final targetAngle = _normalizeDegrees(
      math.atan2(mathDy, mathDx) * 180.0 / math.pi,
    );

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

  double _shortestArc(double angle) {
    var a = angle % 360;
    if (a < -180) a += 360;
    if (a >= 180) a -= 360;
    return a;
  }

  void _handleAudioGuidance(ArTrackingUpdate update, LocalizedPose localizedPose) {
    // State transition cues
    if (update.state != _lastState) {
      if (update.state == ArTrackingState.arrived) {
        unawaited(_soundService.playCue(GuidanceEventType.arrived));
      } else if (update.state == ArTrackingState.offRoute) {
        unawaited(_soundService.playCue(GuidanceEventType.offRoute));
        unawaited(_soundService.primeDirectionalGuidance());
      } else if (_lastState == ArTrackingState.offRoute &&
          update.state == ArTrackingState.tracking) {
        _soundService.updateDirectionalGuidance(
          isActive: false,
          severity: 0,
          direction: AudioCueDirection.center,
          headingErrorDeg: 180,
          relativeAngleDeg: 0,
          sourceDistanceMeters: 6,
          distanceToWaypointMeters: 6,
        );
      }
      _lastState = update.state;
    }

    // Waypoint advance/regress cues
    if (update.nextWaypointIndex > _lastWaypointIndex) {
      unawaited(_soundService.playCue(GuidanceEventType.waypointAdvanced));
    } else if (update.nextWaypointIndex < _lastWaypointIndex) {
      unawaited(_soundService.playCue(GuidanceEventType.waypointRegressed));
    }
    _lastWaypointIndex = update.nextWaypointIndex;

    // Continuous directional guidance while off-route
    if (update.state == ArTrackingState.offRoute) {
      final mpp = (_metersPerPixel == 1.0) ? 0.05 : (_metersPerPixel ?? 0.05);
      final (headingErrorDeg, relativeAngleDeg, direction) =
          _computeDirectionalGuidance(update, localizedPose);

      _soundService.updateDirectionalGuidance(
        isActive: true,
        severity: update.offRouteSeverity,
        direction: direction,
        headingErrorDeg: headingErrorDeg,
        relativeAngleDeg: relativeAngleDeg,
        sourceDistanceMeters: update.distanceToPathPx * mpp,
        distanceToWaypointMeters: update.distanceToNextWaypointPx * mpp,
      );
    }
  }

  (double headingErrorDeg, double relativeAngleDeg, AudioCueDirection direction)
      _computeDirectionalGuidance(ArTrackingUpdate update, LocalizedPose pose) {
    if (_route == null || _route!.steps.isEmpty) {
      return (180, 0, AudioCueDirection.center);
    }

    final routePoints = _route!.steps
        .map((s) => Offset(s.from.x, s.from.y))
        .toList();
    routePoints.add(Offset(_route!.steps.last.to.x, _route!.steps.last.to.y));

    final waypoint =
        routePoints[update.nextWaypointIndex.clamp(0, routePoints.length - 1)];

    final mathDx = waypoint.dx - pose.x;
    final mathDy = waypoint.dy - pose.y;
    final targetAngle =
        _normalizeDegrees(math.atan2(mathDy, mathDx) * 180.0 / math.pi);

    final headingDelta = _signedHeadingDeltaDeg(pose.heading, targetAngle);
    final headingErrorDeg = headingDelta.abs();
    final relativeAngleDeg = headingDelta;

    final AudioCueDirection direction;
    if (headingErrorDeg < 15) {
      direction = AudioCueDirection.center;
    } else if (headingDelta > 0) {
      direction = AudioCueDirection.right;
    } else {
      direction = AudioCueDirection.left;
    }

    return (headingErrorDeg, relativeAngleDeg, direction);
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
    // _compassDeltaDeg corrects for user rotation between image capture and route plot:
    //   if user turned 90° left during loading, path shifts 90° right in AR world.
    final captureHeading = _normalizeDegrees(origin.heading);
    final sumHeadingDeg = _normalizeDegrees(
      reference.heading + captureHeading + _compassDeltaDeg,
    );
    final sumHeadingRad = sumHeadingDeg * math.pi / 180.0;

    // Origin pose in math-plane (East, North).
    final originWorldX = origin.worldX ?? origin.x;
    final originWorldZ = origin.worldZ ?? -origin.y;
    final originMathX = originWorldX;
    final originMathY = -originWorldZ; // North

    // Reference in math-plane (flip Y from image).
    final refMathX = reference.x;
    final refMathY = -reference.y;

    // Path height: knee level (~0.5 m above floor, camera at ~1.5 m height).
    // Offset = cameraHeight - kneeHeight = 1.5 - 0.5 = 1.0 m.
    // Increase to lower the path; decrease to raise it.
    const _pathHeightOffsetM = 1.0;
    final cameraWorldY = origin.worldY ?? origin.z;
    final floorWorldY = cameraWorldY - _pathHeightOffsetM;

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
    _soundService.updateDirectionalGuidance(
      isActive: false,
      severity: 0,
      direction: AudioCueDirection.center,
      headingErrorDeg: 180,
      relativeAngleDeg: 0,
      sourceDistanceMeters: 6,
      distanceToWaypointMeters: 6,
    );
    return super.close();
  }
}
