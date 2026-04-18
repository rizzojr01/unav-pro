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

    _originArPose ??= event.pose;

    // Use a realistic fallback if metersPerPixel is 1.0 (unscaled)
    final effectiveMpp = (_metersPerPixel == 1.0) ? 0.05 : _metersPerPixel!;

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

    _handleAudioGuidance(update);
    _handleArOverlay(update, localizedPose);

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
    final dx = waypoint.dx - pose.x;
    final dy = waypoint.dy - pose.y;

    // Bearing in floorplan space (0=East, 90=South [Clockwise])
    final mathDx = waypoint.dx - pose.x;
    final mathDy = waypoint.dy - pose.y;

    // targetAngle is the angle (0=East, 90=South) we want the user to face
    final targetAngle = _normalizeDegrees(
      math.atan2(mathDy, mathDx) * 180.0 / math.pi,
    );

    // pose.heading is in the same system (0=East, 90=South [Clockwise])
    final headingDelta = _signedHeadingDeltaDeg(pose.heading, targetAngle);
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

    // Convert pixels to meters relative to origin for AR engine
    // originArPose is (0,0,0) in AR space
    // referencePose is (rx, ry) in pixels on floorplan
    // currentPose is (cx, cy) in pixels on floorplan
    // AR space (x,z) roughly corresponds to floorplan (dx, dy)

    List<double> pixelToAr(double px, double py) {
      final dx = px - _referencePose!.x;
      final dy = py - _referencePose!.y;

      // referencePose.heading is 0=East, 90=South, 180=West, 270=North (Clockwise)
      // AR -Z is forward. Phone is currently facing referencePose.heading.

      // To align AR -Z (forward) with the user's initial heading:
      // We need to rotate the floorplan points by an offset that maps
      // the user's heading to -Z.

      // In a standard unit circle (0=East, 90=South):
      // East (0) -> AR X+
      // South (90) -> AR Z+
      // West (180) -> AR X-
      // North (270) -> AR Z- (Forward)

      // Since the user is facing 'heading', we need to rotate the world
      // so that 'heading' aligns with the phone's forward axis.
      final rad = (_referencePose!.heading) * math.pi / 180.0;

      // We rotate the floorplan offset by -rad to bring it into
      // the camera's local coordinate system.
      final cos = math.cos(-rad);
      final sin = math.sin(-rad);

      // Rotate dx (East), dy (South) into local AR space
      final localX = (dx * cos - dy * sin) * mpp;
      final localZ = (dx * sin + dy * cos) * mpp;

      // Because AR uses -Z for forward, we need to check if the axes
      // match our expectations.
      // With 270=North, sin(270)=-1, cos(270)=0.
      // localX = (dx*0 - dy*-1) = dy
      // localZ = (dx*-1 + dy*0) = -dx

      // Actually, if we are facing North (270), and the path is North (dy < 0):
      // We want that point to be at -Z.

      // Let's use a simpler approach:
      // 1. Convert Heading to a standard math angle (0=East, 90=North)
      //    MathAngle = -heading (because heading is clockwise)
      // 2. Rotate floorplan by -MathAngle to align East with X+
      // 3. Then rotate by -90 to align North with Z-

      final mathRad = (-_referencePose!.heading) * math.pi / 180.0;
      final c = math.cos(mathRad);
      final s = math.sin(mathRad);

      // Rotate such that the 'heading' vector becomes (1, 0)
      // Then rotate by 90 deg to make it (0, 1) or (0, -1)

      // Corrected rotation for AR alignment:
      // We want to rotate the floorplan so that the vector 'heading'
      // points towards (0, 0, -1) in AR.

      final angleToForward = (90.0 + _referencePose!.heading) * math.pi / 180.0;
      final cosA = math.cos(angleToForward);
      final sinA = math.sin(angleToForward);

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
