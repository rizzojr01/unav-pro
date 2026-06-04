import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';
import 'package:smart_sense/shared/services/location_config_service.dart';
import 'package:smart_sense/core/utils/logger.dart';
import 'package:smart_sense/core/utils/route_snap.dart';
import 'package:smart_sense/injection.dart';
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
  final LocationConfigService _locationConfig;
  final AppLogger _logger = getIt<AppLogger>();

  double? _metersPerPixel;
  LocalizedPose? _referencePose;
  RouteEntity? _route;
  ArPose? _originArPose;
  ArTrackingState? _lastState;
  int _lastWaypointIndex = 0;
  bool _wasApproachingWaypoint = false;
  bool? _lastHeadingAligned;
  double? _lastFrameHeading;
  double? _lastFrameConfidence;
  int _ignoredOriginFrameCount = 0;
  final List<ArPose> _originPoseCandidates = [];
  DateTime? _originStabilizationStartedAt;
  double _arTravelDistance = 0.0;
  ArPose? _lastPoseForDistance;

  static const double _headingLockThresholdDeg = 8.0;
  static const double _minimumOriginConfidence = 1.0;
  static const int _originStableFrameCount = 6;
  static const double _originMaxHeadingSpreadDeg = 4.0;
  static const double _originMaxPositionSpreadM = 0.35;
  static const Duration _minimumOriginSettleDuration =
      Duration(milliseconds: 700);
  static const Duration _maximumOriginWaitDuration = Duration(seconds: 3);

  StreamSubscription? _poseSubscription;

  ArNavigationBloc({
    required ArPoseRepository poseRepository,
    required ArPoseTransformer poseTransformer,
    required PathTrackingService pathTracker,
    required GuidanceSoundService soundService,
    required LocationConfigService locationConfig,
  })  : _poseRepository = poseRepository,
        _poseTransformer = poseTransformer,
        _pathTracker = pathTracker,
        _soundService = soundService,
        _locationConfig = locationConfig,
        super(const ArNavigationInitial()) {
    on<StartArNavigation>(_onStartNavigation);
    on<UpdateArPose>(_onUpdatePose);
    on<StopArNavigation>(_onStopNavigation);

    _locationConfig.unitNotifier.addListener(_onUnitChanged);
  }

  void _onUnitChanged() {
    _soundService.unit = _locationConfig.unit;
  }

  Future<void> _onStartNavigation(
    StartArNavigation event,
    Emitter<ArNavigationState> emit,
  ) async {
    _referencePose = event.referencePose;
    _route = event.route;

    // AR world tracking is always metric. The route model normalizes this
    // value to meters-per-pixel before AR navigation starts; display unit only
    // affects formatted guidance text/audio.
    double mpp = event.metersPerPixel;
    if (mpp == 1.0) {
      mpp = 0.05; // Use fallback for unscaled/invalid backend values
    }
    _metersPerPixel = mpp;
    _originArPose = event.originArPose;
    _arTravelDistance = 0.0;
    _lastPoseForDistance = event.originArPose;
    _lastState = ArTrackingState.idle;
    _lastWaypointIndex = 0;
    _wasApproachingWaypoint = false;
    _lastHeadingAligned = null;
    _lastFrameHeading = null;
    _lastFrameConfidence = null;
    _ignoredOriginFrameCount = 0;
    if (event.originArPose == null) {
      _resetOriginStabilization();
    } else {
      _originPoseCandidates
        ..clear()
        ..add(event.originArPose!);
      _originStabilizationStartedAt = event.originArPose!.timestamp;
    }

    _logger.info('🚀 ArNavigationBloc: Starting AR Navigation\n'
        '  - Place: ${_locationConfig.place}\n'
        '  - Building: ${_locationConfig.building}\n'
        '  - Floor: ${event.referencePose.floorKey}\n'
        '  - API Reference Heading (API Ang): ${event.referencePose.heading.toStringAsFixed(1)}°\n'
        '  - Raw MetersPerPixel: ${event.metersPerPixel}\n'
        '  - Effective MetersPerPixel (unit: ${_locationConfig.unit}): $mpp\n'
        '  - Capture AR Origin: ${event.originArPose == null ? "pending first stable frame" : "provided"}');

    await _soundService.init();

    await _poseSubscription?.cancel();
    _poseSubscription = _poseRepository.watchPose().listen((pose) {
      add(UpdateArPose(pose));
    });

    await _poseRepository.start();
    if (event.originArPose != null) {
      _logger.info('🏁 AR NAVIGATION POINT ZERO RESTORED FROM CAPTURE!\n'
          '  - Origin AR Heading (Yaw): ${event.originArPose!.heading.toStringAsFixed(1)}°\n'
          '  - Origin Position: (x: ${event.originArPose!.x.toStringAsFixed(2)}, y: ${event.originArPose!.y.toStringAsFixed(2)}, z: ${event.originArPose!.z.toStringAsFixed(2)})\n'
          '  - Origin Confidence: ${event.originArPose!.confidence.toStringAsFixed(2)}\n'
          '  - API Reference Heading: ${_referencePose!.heading.toStringAsFixed(1)}°\n'
          '  - Initial Calculated sumHeadingDeg: ${((_referencePose!.heading + event.originArPose!.heading) % 360.0).toStringAsFixed(1)}°');
    }
    _emitArLogSessionHeader(mpp);
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

  void _emitArLogSessionHeader(double mpp) {
    if (_referencePose == null || _route == null) return;
    final routePts = <List<double>>[];
    for (final step in _route!.steps) {
      routePts.add([step.from.x, step.from.y]);
    }
    if (_route!.steps.isNotEmpty) {
      routePts.add([_route!.steps.last.to.x, _route!.steps.last.to.y]);
    }
    final payload = <String, dynamic>{
      't': 'session',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'place': _locationConfig.place,
      'building': _locationConfig.building,
      'floor': _referencePose!.floorKey,
      'mpp': mpp,
      'arHeadingOffsetDeg': _locationConfig.arHeadingOffsetDeg,
      'reference': {
        'x': _referencePose!.x,
        'y': _referencePose!.y,
        'heading': _referencePose!.heading,
      },
      'origin': _originArPose == null
          ? null
          : {
              'x': _originArPose!.x,
              'y': _originArPose!.y,
              'z': _originArPose!.z,
              'worldX': _originArPose!.worldX,
              'worldY': _originArPose!.worldY,
              'worldZ': _originArPose!.worldZ,
              'heading': _originArPose!.heading,
              'confidence': _originArPose!.confidence,
              'ts': _originArPose!.timestamp.millisecondsSinceEpoch,
            },
      'routeFp': routePts,
    };
    _logger.info('AR_LOG ${jsonEncode(payload)}');
  }

  void _emitArLogFrame({
    required ArPose rawAr,
    required LocalizedPose localized,
    required ArTrackingUpdate update,
  }) {
    if (_referencePose == null || _originArPose == null) return;
    final captureHeading = _normalizeDegrees(_originArPose!.heading);
    final sumHeadingDeg = _normalizeDegrees(
      _referencePose!.heading +
          captureHeading +
          _locationConfig.arHeadingOffsetDeg,
    );
    final payload = <String, dynamic>{
      't': 'frame',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'offset': _locationConfig.arHeadingOffsetDeg,
      'sumDeg': sumHeadingDeg,
      'ar': {
        'x': rawAr.x,
        'y': rawAr.y,
        'z': rawAr.z,
        'wX': rawAr.worldX,
        'wY': rawAr.worldY,
        'wZ': rawAr.worldZ,
        'heading': rawAr.heading,
        'conf': rawAr.confidence,
      },
      'fp': {
        'x': localized.x,
        'y': localized.y,
        'z': localized.z,
        'heading': localized.heading,
      },
      'state': update.state.toString().split('.').last,
      'nextWp': update.nextWaypointIndex,
      'remPx': update.remainingDistancePx,
      'distNextPx': update.distanceToNextWaypointPx,
      'travelM': _arTravelDistance,
    };
    _logger.info('AR_LOG ${jsonEncode(payload)}');
  }

  Future<void> _onStopNavigation(
    StopArNavigation event,
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

  void _onUpdatePose(
    UpdateArPose event,
    Emitter<ArNavigationState> emit,
  ) {
    if (_referencePose == null || _metersPerPixel == null || _route == null) {
      return;
    }

    final isFirstFrame = _originArPose == null;
    if (isFirstFrame) {
      final stableOriginPose = _selectStableOriginPose(event.pose);
      if (stableOriginPose == null) {
        _ignoredOriginFrameCount++;
        _logger.warning(
            '⏳ AR origin frame ignored while tracking initializes:\n'
            '  - Ignored Frames: $_ignoredOriginFrameCount\n'
            '  - Candidate Heading: ${event.pose.heading.toStringAsFixed(1)}°\n'
            '  - Candidate Confidence: ${event.pose.confidence.toStringAsFixed(2)}\n'
            '  - Required Confidence: ${_minimumOriginConfidence.toStringAsFixed(2)}\n'
            '  - Stable Candidates: ${_originPoseCandidates.length}/$_originStableFrameCount');
        _lastFrameHeading = event.pose.heading;
        _lastFrameConfidence = event.pose.confidence;
        return;
      }

      _originArPose = stableOriginPose;
      _lastPoseForDistance = stableOriginPose;
      _arTravelDistance = 0.0;
      _logger.info('🏁 AR NAVIGATION POINT ZERO INITIALIZED!\n'
          '  - Origin AR Heading (Yaw): ${stableOriginPose.heading.toStringAsFixed(1)}°\n'
          '  - Origin Position: (x: ${stableOriginPose.x.toStringAsFixed(2)}, y: ${stableOriginPose.y.toStringAsFixed(2)}, z: ${stableOriginPose.z.toStringAsFixed(2)})\n'
          '  - Origin Confidence: ${stableOriginPose.confidence.toStringAsFixed(2)}\n'
          '  - Ignored Startup Frames: $_ignoredOriginFrameCount\n'
          '  - Stable Startup Frames: ${_originPoseCandidates.length}\n'
          '  - API Reference Heading: ${_referencePose!.heading.toStringAsFixed(1)}°\n'
          '  - Initial Calculated sumHeadingDeg: ${((_referencePose!.heading + stableOriginPose.heading) % 360.0).toStringAsFixed(1)}°');
      _resetOriginStabilization();
    } else {
      if (_lastPoseForDistance != null) {
        final currentX = event.pose.worldX ?? event.pose.x;
        final currentY = event.pose.worldY ?? event.pose.y;
        final currentZ = event.pose.worldZ ?? event.pose.z;

        final lastX = _lastPoseForDistance!.worldX ?? _lastPoseForDistance!.x;
        final lastY = _lastPoseForDistance!.worldY ?? _lastPoseForDistance!.y;
        final lastZ = _lastPoseForDistance!.worldZ ?? _lastPoseForDistance!.z;

        final dx = currentX - lastX;
        final dy = currentY - lastY;
        final dz = currentZ - lastZ;
        final stepDistance = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (stepDistance >= 0.05) {
          _arTravelDistance += stepDistance;
          _lastPoseForDistance = event.pose;
        }
      }

      // 1. Detect Real Sensor Flicks (sudden frame-to-frame snaps)
      if (_lastFrameHeading != null) {
        final double frameDelta =
            (event.pose.heading - _lastFrameHeading!) % 360.0;
        final double normalizedFrameDelta =
            frameDelta > 180.0 ? frameDelta - 360.0 : frameDelta;

        if (normalizedFrameDelta.abs() > 8.0) {
          _logger.warning('⚡ AR Sensor Flick/Snap Detected:\n'
              '  - Previous Frame Heading: ${_lastFrameHeading!.toStringAsFixed(1)}°\n'
              '  - New Calibrated Heading: ${event.pose.heading.toStringAsFixed(1)}°\n'
              '  - Sudden Snap Delta: ${normalizedFrameDelta.toStringAsFixed(1)}°\n'
              '  - Tracking Confidence: ${event.pose.confidence.toStringAsFixed(2)}');
        }
      }

      // 2. Log Tracking Confidence Transitions (e.g. limited -> normal)
      if (_lastFrameConfidence != null &&
          event.pose.confidence != _lastFrameConfidence) {
        _logger.info('📶 Tracking Confidence Transition:\n'
            '  - Previous Confidence: ${_lastFrameConfidence!.toStringAsFixed(2)}\n'
            '  - New Confidence: ${event.pose.confidence.toStringAsFixed(2)}\n'
            '  - Current Raw Heading: ${event.pose.heading.toStringAsFixed(1)}°');
      }
    }

    // Keep history of the previous frame state for real-time differential tracking
    _lastFrameHeading = event.pose.heading;
    _lastFrameConfidence = event.pose.confidence;

    // Use already-corrected metersPerPixel from _onStartNavigation
    final effectiveMpp = _metersPerPixel ?? 0.05;

    // ArPoseTransformer now produces correctly-aligned FP coordinates and
    // heading directly from ARKit's gravityAndHeading world frame.
    // No additional delta correction is needed — the session's compass
    // alignment handles it at the native layer.
    var localizedPose = _poseTransformer.transform(
      currentArPose: event.pose,
      originArPose: _originArPose!,
      referenceFloorplanPose: _referencePose!,
      metersPerPixel: effectiveMpp,
      headingOffsetDeg: _locationConfig.arHeadingOffsetDeg,
    );

    // Snap (x,y) onto nearest navigable corridor edge. Heading/confidence/
    // timestamp untouched. Threshold (px) prevents stray-pose teleport.
    final segments = _route?.routeNetworkSegments ?? const [];
    if (_locationConfig.snapToRoute && segments.isNotEmpty) {
      final snapThresholdPx = 2.0 / effectiveMpp; // ~2 m
      final snapped = snapToRouteNetwork(
        Offset(localizedPose.x, localizedPose.y),
        segments,
        thresholdPx: snapThresholdPx,
      );
      if (snapped.dx != localizedPose.x || snapped.dy != localizedPose.y) {
        localizedPose = localizedPose.copyWith(x: snapped.dx, y: snapped.dy);
      }
    }

    // Trace starting coordinate alignment mapping on Frame 1
    if (isFirstFrame) {
      _logger.info('📍 AR First Localized Coordinates calculated:\n'
          '  - Raw Screen Coordinates: (x: ${localizedPose.x.toStringAsFixed(1)}, y: ${localizedPose.y.toStringAsFixed(1)})\n'
          '  - Initial Transformed User Heading (fpHeading): ${localizedPose.heading.toStringAsFixed(1)}°');
    }

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

    _emitArLogFrame(
      rawAr: event.pose,
      localized: localizedPose,
      update: update,
    );

    emit(
      ArNavigationTracking(
        currentPose: localizedPose,
        state: update.state,
        trackedPath: update.trackedPath,
        nextWaypointIndex: update.nextWaypointIndex,
        remainingDistancePx: update.remainingDistancePx,
        distanceToNextWaypointPx: update.distanceToNextWaypointPx,
        guidanceMessage: guidanceMessage,
        arTravelDistance: _arTravelDistance,
      ),
    );
  }

  String? _buildGuidanceMessage(ArTrackingUpdate update, LocalizedPose pose) {
    if (update.state == ArTrackingState.offRoute) return null;
    if (update.state == ArTrackingState.arrived) {
      return 'Arrived at the destination.';
    }

    if (_route == null || _route!.steps.isEmpty) return null;

    final routePoints =
        _route!.steps.map((s) => Offset(s.from.x, s.from.y)).toList();
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
    final effectiveMpp = _metersPerPixel ?? 0.05;
    final distanceMeters = update.distanceToNextWaypointPx * effectiveMpp;
    final distanceText = _formatDistance(distanceMeters);

    if (angle <= 25) {
      return 'Go straight for $distanceText.';
    }

    final dir = headingDelta > 0 ? 'right' : 'left';
    return 'Turn $dir $angle°, then go $distanceText.';
  }

  String _formatDistance(double distanceMeters) {
    final unit = _soundService.unit;
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

  bool _isUsableOriginPose(ArPose pose) {
    return pose.confidence >= _minimumOriginConfidence &&
        pose.heading.isFinite &&
        pose.x.isFinite &&
        pose.y.isFinite &&
        pose.z.isFinite;
  }

  ArPose? _selectStableOriginPose(ArPose pose) {
    if (!_isUsableOriginPose(pose)) {
      _resetOriginStabilization();
      return null;
    }

    _originStabilizationStartedAt ??= DateTime.now();
    _originPoseCandidates.add(pose);
    if (_originPoseCandidates.length > _originStableFrameCount) {
      _originPoseCandidates.removeAt(0);
    }

    final settleElapsed =
        DateTime.now().difference(_originStabilizationStartedAt!);
    final hasEnoughFrames =
        _originPoseCandidates.length >= _originStableFrameCount;
    final hasSettled = settleElapsed >= _minimumOriginSettleDuration;

    if (hasEnoughFrames && hasSettled && _originWindowIsStable()) {
      return _averageOriginPose(_originPoseCandidates);
    }

    if (settleElapsed >= _maximumOriginWaitDuration &&
        _originPoseCandidates.isNotEmpty) {
      final fallback = _averageOriginPose(_originPoseCandidates);
      _logger.warning('AR origin stability timeout; using best candidate:\n'
          '  - Waited: ${settleElapsed.inMilliseconds} ms\n'
          '  - Candidate Frames: ${_originPoseCandidates.length}\n'
          '  - Averaged Heading: ${fallback.heading.toStringAsFixed(1)} deg');
      return fallback;
    }

    return null;
  }

  bool _originWindowIsStable() {
    if (_originPoseCandidates.length < _originStableFrameCount) return false;

    final headings = _originPoseCandidates
        .map((pose) => _normalizeDegrees(pose.heading))
        .toList(growable: false);
    final meanHeading = _circularMeanDegrees(headings);
    final maxHeadingError = headings
        .map((heading) => _signedHeadingDeltaDeg(meanHeading, heading).abs())
        .fold<double>(0.0, math.max);

    final first = _originPoseCandidates.first;
    final firstX = first.worldX ?? first.x;
    final firstY = first.worldY ?? first.y;
    final firstZ = first.worldZ ?? first.z;
    final maxPositionDelta = _originPoseCandidates.map((candidate) {
      final dx = (candidate.worldX ?? candidate.x) - firstX;
      final dy = (candidate.worldY ?? candidate.y) - firstY;
      final dz = (candidate.worldZ ?? candidate.z) - firstZ;
      return math.sqrt(dx * dx + dy * dy + dz * dz);
    }).fold<double>(0.0, math.max);

    return maxHeadingError <= _originMaxHeadingSpreadDeg &&
        maxPositionDelta <= _originMaxPositionSpreadM;
  }

  ArPose _averageOriginPose(List<ArPose> poses) {
    final latest = poses.last;
    final averagedHeading = _circularMeanDegrees(
      poses.map((pose) => _normalizeDegrees(pose.heading)),
    );
    return latest.copyWith(heading: averagedHeading);
  }

  double _circularMeanDegrees(Iterable<double> headings) {
    double sinSum = 0;
    double cosSum = 0;
    var count = 0;
    for (final heading in headings) {
      final radians = heading * math.pi / 180.0;
      sinSum += math.sin(radians);
      cosSum += math.cos(radians);
      count++;
    }
    if (count == 0) return 0;
    return _normalizeDegrees(math.atan2(sinSum, cosSum) * 180.0 / math.pi);
  }

  void _resetOriginStabilization() {
    _originPoseCandidates.clear();
    _originStabilizationStartedAt = null;
  }

  void _handleAudioGuidance(
      ArTrackingUpdate update, LocalizedPose localizedPose) {
    final effectiveMpp = _metersPerPixel ?? 0.05;
    final distanceMeters = update.distanceToNextWaypointPx * effectiveMpp;

    // State transition cues
    if (update.state != _lastState) {
      if (update.state == ArTrackingState.arrived) {
        unawaited(_soundService.playCue(GuidanceEventType.arrived));
      } else if (update.state == ArTrackingState.offRoute) {
        unawaited(_soundService.playCue(GuidanceEventType.offRoute));
        unawaited(_soundService.primeDirectionalGuidance());
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

    // Approaching-waypoint cue: fires once on threshold crossing
    if (update.isApproachingWaypoint && !_wasApproachingWaypoint) {
      unawaited(_soundService.playCue(GuidanceEventType.approachingWaypoint));
    }
    _wasApproachingWaypoint = update.isApproachingWaypoint;

    // Heading latch haptic: edge-triggered on alignment with next waypoint
    final signedDelta =
        _signedHeadingDeltaToNextWaypoint(update, localizedPose);
    final headingErrorDeg = signedDelta.abs();
    final headingAligned = headingErrorDeg <= _headingLockThresholdDeg;
    if (update.state == ArTrackingState.tracking) {
      _emitHeadingLatchHapticIfNeeded(headingAligned);
    } else {
      _lastHeadingAligned = null;
    }

    // Continuous directional guidance — active whenever there are waypoints ahead,
    // matching reference: always on except at arrived/localizing.
    final isActive = update.trackedPath.length >= 2 &&
        update.state != ArTrackingState.arrived &&
        update.state != ArTrackingState.localizing;

    final headingDirection = headingAligned
        ? AudioCueDirection.center
        : (signedDelta > 0 ? AudioCueDirection.right : AudioCueDirection.left);

    final severity = update.state == ArTrackingState.offRoute
        ? update.offRouteSeverity.clamp(0.35, 1.0)
        : _normalizedHeadingSeverity(headingErrorDeg);

    final direction = update.state == ArTrackingState.offRoute
        ? update.offRouteDirection
        : headingDirection;

    _soundService.updateDirectionalGuidance(
      isActive: isActive,
      severity: severity,
      direction: direction,
      headingErrorDeg: headingErrorDeg,
      relativeAngleDeg: signedDelta,
      sourceDistanceMeters: 6.0,
      distanceToWaypointMeters: distanceMeters,
    );
  }

  double _normalizedHeadingSeverity(double headingErrorDeg) {
    const start = _headingLockThresholdDeg;
    const end = 70.0;
    return ((headingErrorDeg - start) / (end - start)).clamp(0.0, 1.0);
  }

  double _signedHeadingDeltaToNextWaypoint(
    ArTrackingUpdate update,
    LocalizedPose pose,
  ) {
    if (_route == null || _route!.steps.isEmpty) return 180;
    final routePoints =
        _route!.steps.map((s) => Offset(s.from.x, s.from.y)).toList();
    routePoints.add(Offset(_route!.steps.last.to.x, _route!.steps.last.to.y));
    final idx = update.nextWaypointIndex.clamp(0, routePoints.length - 1);
    final waypoint = routePoints[idx];
    final dx = waypoint.dx - pose.x;
    final dy = waypoint.dy - pose.y;
    if (Offset(dx, dy).distance <= 1e-3) return 0;
    final bearingDeg = _normalizeDegrees(math.atan2(dy, dx) * 180.0 / math.pi);
    return _signedHeadingDeltaDeg(pose.heading, bearingDeg);
  }

  void _emitHeadingLatchHapticIfNeeded(bool headingAligned) {
    final previous = _lastHeadingAligned;
    _lastHeadingAligned = headingAligned;
    if (previous == null || previous == headingAligned) return;
    unawaited(_playLatchHaptic(lockedIn: headingAligned));
  }

  Future<void> _playLatchHaptic({required bool lockedIn}) async {
    if (lockedIn) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 35));
      await HapticFeedback.selectionClick();
    } else {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await HapticFeedback.lightImpact();
    }
  }

  void _handleArOverlay(ArTrackingUpdate update, LocalizedPose currentPose) {
    if (_route == null || _originArPose == null || _referencePose == null) {
      return;
    }

    final effectiveMpp = _metersPerPixel ?? 0.05;
    final reference = _referencePose!;
    final origin = _originArPose!;

    // Matches ar_temp _floorplanPointToArWorld:
    //   sumHeadingDeg = reference.heading + captureHeading (AR yaw at session start).
    // Must use identical angle as ArPoseTransformer (forward direction) so path and
    // tracked position share the same rotation frame. Includes the live-tunable
    // heading offset so adjustments rotate the AR path overlay in real time.
    final captureHeading = _normalizeDegrees(origin.heading);
    final sumHeadingDeg = _normalizeDegrees(
      reference.heading + captureHeading + _locationConfig.arHeadingOffsetDeg,
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
    const pathHeightOffsetM = 1.0;
    final cameraWorldY = origin.worldY ?? origin.z;
    final floorWorldY = cameraWorldY - pathHeightOffsetM;

    // Converts a floorplan image point to ARKit world-space [worldX, worldY, worldZ].
    List<double> floorplanToArWorld(double px, double py) {
      // Image → math plane
      final mathX = px;
      final mathY = -py;

      final deltaMetersX = (mathX - refMathX) * effectiveMpp;
      final deltaMetersY = (mathY - refMathY) * effectiveMpp;

      // CCW rotation by sumHeadingRad (inverse of _transformTrackedPose CW rotation)
      final arDeltaX = deltaMetersX * math.cos(sumHeadingRad) -
          deltaMetersY * math.sin(sumHeadingRad);
      final arDeltaY = deltaMetersX * math.sin(sumHeadingRad) +
          deltaMetersY * math.cos(sumHeadingRad);

      final targetMathX = originMathX + arDeltaX;
      final targetMathY = originMathY + arDeltaY;

      // Math plane (East, North) → AR world: worldX = East, worldZ = −North
      final worldX = targetMathX;
      final worldZ = -targetMathY;

      return [worldX, floorWorldY, worldZ];
    }

    final routePoints =
        _route!.steps.map((s) => Offset(s.from.x, s.from.y)).toList();
    routePoints.add(Offset(_route!.steps.last.to.x, _route!.steps.last.to.y));

    final allPathAr =
        routePoints.map((p) => floorplanToArWorld(p.dx, p.dy)).toList();

    final nextWaypoint = routePoints[update.nextWaypointIndex];

    _poseRepository.updateOverlay(
      pathPoints: allPathAr,
      activePathPoints: allPathAr,
      futurePathPoints: const [],
      nextWaypoint: floorplanToArWorld(nextWaypoint.dx, nextWaypoint.dy),
      destination: floorplanToArWorld(routePoints.last.dx, routePoints.last.dy),
    );
  }

  @override
  Future<void> close() {
    _locationConfig.unitNotifier.removeListener(_onUnitChanged);
    _poseSubscription?.cancel();
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
