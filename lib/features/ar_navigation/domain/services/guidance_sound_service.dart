import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/spatial_audio_channel_contract.dart';
import '../models/audio_cue_direction.dart';
import '../models/guidance_event_type.dart';

enum GuidanceAudioMode {
  auto,
  stereo,
  spatial,
}

class AudioOutputStatus {
  final bool supportsSpatial;
  final bool supportsStereoPan;
  final bool isMonoAudioEnabled;
  final bool hasHeadphonesConnected;

  const AudioOutputStatus({
    required this.supportsSpatial,
    required this.supportsStereoPan,
    required this.isMonoAudioEnabled,
    required this.hasHeadphonesConnected,
  });

  const AudioOutputStatus.unknown()
      : supportsSpatial = false,
        supportsStereoPan = false,
        isMonoAudioEnabled = false,
        hasHeadphonesConnected = false;
}

class GuidanceSoundService {
  final GuidanceAudioMode preferredMode;
  late final _GuidanceAudioRenderer _stereoRenderer;
  late final _MethodChannelSpatialAudioRenderer _spatialRenderer;
  _GuidanceAudioRenderer? _activeRenderer;
  _DirectionalGuidanceState _lastDirectionalState = const _DirectionalGuidanceState.inactive();
  bool _initialized = false;

  GuidanceSoundService({
    this.preferredMode = GuidanceAudioMode.auto,
    AudioPlayer? eventPlayer,
    AudioPlayer? offRoutePlayer,
  }) {
    _stereoRenderer = _StereoGuidanceAudioRenderer(
      eventPlayer: eventPlayer,
      offRoutePlayer: offRoutePlayer,
    );
    _spatialRenderer = _MethodChannelSpatialAudioRenderer();
  }

  Future<void> init() async {
    if (_initialized) return;
    await _stereoRenderer.init();
    _activeRenderer = _stereoRenderer;
    _initialized = true;

    if (preferredMode == GuidanceAudioMode.spatial) {
      await enableSpatial();
    }
  }

  Future<void> dispose() async {
    _initialized = false;
    if (!identical(_activeRenderer, _stereoRenderer)) {
      await _activeRenderer?.dispose();
    }
    await _stereoRenderer.dispose();
  }

  Future<void> primeDirectionalGuidance() async {
    await (_activeRenderer ?? _stereoRenderer).primeDirectionalGuidance();
  }

  bool get isUsingSpatialRenderer => identical(_activeRenderer, _spatialRenderer);

  Future<bool> enableSpatial() async {
    if (isUsingSpatialRenderer) return true;
    _stereoRenderer.updateDirectionalGuidance(
      isActive: false,
      severity: 0,
      direction: AudioCueDirection.center,
      headingErrorDeg: 180,
      relativeAngleDeg: 0,
      sourceDistanceMeters: 6,
      distanceToWaypointMeters: 6,
    );
    final supportsSpatial = await _spatialRenderer.canUseSpatialAudio();
    if (!supportsSpatial) return false;
    await _spatialRenderer.init();
    _activeRenderer = _spatialRenderer;
    _applyDirectionalStateToActiveRenderer();
    return true;
  }

  Future<void> disableSpatial() async {
    if (!isUsingSpatialRenderer) return;
    _spatialRenderer.updateDirectionalGuidance(
      isActive: false,
      severity: 0,
      direction: AudioCueDirection.center,
      headingErrorDeg: 180,
      relativeAngleDeg: 0,
      sourceDistanceMeters: 6,
      distanceToWaypointMeters: 6,
    );
    await _spatialRenderer.dispose();
    _activeRenderer = _stereoRenderer;
    _applyDirectionalStateToActiveRenderer();
  }

  void updateDirectionalGuidance({
    required bool isActive,
    required double severity,
    required AudioCueDirection direction,
    required double headingErrorDeg,
    required double relativeAngleDeg,
    required double sourceDistanceMeters,
    required double distanceToWaypointMeters,
  }) {
    _lastDirectionalState = _DirectionalGuidanceState(
      isActive: isActive,
      severity: severity,
      direction: direction,
      headingErrorDeg: headingErrorDeg,
      relativeAngleDeg: relativeAngleDeg,
      sourceDistanceMeters: sourceDistanceMeters,
      distanceToWaypointMeters: distanceToWaypointMeters,
    );
    (_activeRenderer ?? _stereoRenderer).updateDirectionalGuidance(
      isActive: isActive,
      severity: severity,
      direction: direction,
      headingErrorDeg: headingErrorDeg,
      relativeAngleDeg: relativeAngleDeg,
      sourceDistanceMeters: sourceDistanceMeters,
      distanceToWaypointMeters: distanceToWaypointMeters,
    );
  }

  void _applyDirectionalStateToActiveRenderer() {
    final renderer = _activeRenderer ?? _stereoRenderer;
    renderer.updateDirectionalGuidance(
      isActive: _lastDirectionalState.isActive,
      severity: _lastDirectionalState.severity,
      direction: _lastDirectionalState.direction,
      headingErrorDeg: _lastDirectionalState.headingErrorDeg,
      relativeAngleDeg: _lastDirectionalState.relativeAngleDeg,
      sourceDistanceMeters: _lastDirectionalState.sourceDistanceMeters,
      distanceToWaypointMeters: _lastDirectionalState.distanceToWaypointMeters,
    );
  }

  Future<void> playCue(GuidanceEventType type) async {
    // Event cues stay on the stable stereo path; only continuous directional
    // guidance is routed to the spatial renderer.
    await _stereoRenderer.playCue(type);
  }

  Future<AudioOutputStatus> getAudioOutputStatus() async {
    return _spatialRenderer.getAudioOutputStatus();
  }
}

abstract class _GuidanceAudioRenderer {
  Future<void> init();
  Future<void> dispose();
  Future<void> primeDirectionalGuidance();
  Future<void> playCue(GuidanceEventType type);
  void updateDirectionalGuidance({
    required bool isActive,
    required double severity,
    required AudioCueDirection direction,
    required double headingErrorDeg,
    required double relativeAngleDeg,
    required double sourceDistanceMeters,
    required double distanceToWaypointMeters,
  });
}

class _StereoGuidanceAudioRenderer implements _GuidanceAudioRenderer {
  static final AssetSource _offRouteChimeLeftAsset =
      AssetSource('sounds/offroute_chime_left.wav');
  static final AssetSource _offRouteChimeRightAsset =
      AssetSource('sounds/offroute_chime_right.wav');
  static final AssetSource _offRouteChimeCenterAsset =
      AssetSource('sounds/offroute_chime_center.wav');
  static final AssetSource _offRouteDrumLeftAsset =
      AssetSource('sounds/offroute_drum_left.wav');
  static final AssetSource _offRouteDrumRightAsset =
      AssetSource('sounds/offroute_drum_right.wav');
  static final AssetSource _offRouteDrumCenterAsset =
      AssetSource('sounds/offroute_drum_center.wav');
  static final AssetSource _waypointPassAsset = AssetSource('sounds/waypoint_pass.wav');
  static final AssetSource _waypointErrorAsset = AssetSource('sounds/waypoint_error.wav');
  static const double _chimeFocusThresholdDeg = 8.0;
  static const double _distanceTempoNearMeters = 0.8;
  static const double _distanceTempoFarMeters = 6.0;

  final AudioPlayer _eventPlayer;
  final AudioPlayer _offRoutePlayer;
  Timer? _guidanceTimer;
  double? _guidanceSeverity;
  AudioCueDirection _guidanceDirection = AudioCueDirection.center;
  double _guidanceHeadingErrorDeg = 180;
  double _distanceToWaypointMeters = _distanceTempoFarMeters;
  bool _guidanceToneActive = false;

  _StereoGuidanceAudioRenderer({AudioPlayer? eventPlayer, AudioPlayer? offRoutePlayer})
      : _eventPlayer = eventPlayer ?? AudioPlayer()..setReleaseMode(ReleaseMode.stop),
        _offRoutePlayer = offRoutePlayer ?? AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  Future<void> init() async {
    try {
      await _eventPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _eventPlayer.setVolume(0.85);
      await _offRoutePlayer.setPlayerMode(PlayerMode.lowLatency);
      await _offRoutePlayer.setVolume(0.85);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _guidanceTimer?.cancel();
    await _eventPlayer.dispose();
    await _offRoutePlayer.dispose();
  }

  @override
  Future<void> primeDirectionalGuidance() async {}

  @override
  void updateDirectionalGuidance({
    required bool isActive,
    required double severity,
    required AudioCueDirection direction,
    required double headingErrorDeg,
    required double relativeAngleDeg,
    required double sourceDistanceMeters,
    required double distanceToWaypointMeters,
  }) {
    if (!isActive) {
      _stopDirectionalGuidance();
      return;
    }

    _guidanceSeverity = severity;
    _guidanceDirection = direction;
    _guidanceHeadingErrorDeg = headingErrorDeg;
    _distanceToWaypointMeters = distanceToWaypointMeters;

    if (_guidanceToneActive) {
      return;
    }
    _guidanceToneActive = true;
    unawaited(_scheduleNextGuidancePulse());
  }

  @override
  Future<void> playCue(GuidanceEventType type) async {
    switch (type) {
      case GuidanceEventType.waypointAdvanced:
        await _playPattern([
          _CueStep(
            asset: _waypointPassAsset,
            balance: 0,
            rate: 1.06,
            volume: 0.88,
            haptic: _CueHaptic.light,
          ),
          _CueStep(asset: _waypointPassAsset, balance: 0, rate: 1.18, volume: 0.98),
          _CueStep(asset: _waypointPassAsset, balance: 0, rate: 1.32, volume: 1.0),
        ], gap: const Duration(milliseconds: 120));
        return;
      case GuidanceEventType.waypointRegressed:
        await _playPattern([
          _CueStep(
            asset: _waypointErrorAsset,
            balance: 0,
            rate: 1.00,
            volume: 0.90,
            haptic: _CueHaptic.light,
          ),
          _CueStep(asset: _waypointErrorAsset, balance: 0, rate: 0.92, volume: 0.78),
        ], gap: const Duration(milliseconds: 140));
        return;
      case GuidanceEventType.approachingWaypoint:
        await _playPattern([
          _CueStep(asset: _offRouteChimeCenterAsset, balance: 0, rate: 1.04, volume: 0.36),
        ]);
        return;
      case GuidanceEventType.turnNow:
        await _playPattern([
          _CueStep(
            asset: _offRouteChimeCenterAsset,
            balance: 0,
            rate: 1.06,
            volume: 0.66,
            haptic: _CueHaptic.medium,
          ),
          _CueStep(asset: _waypointPassAsset, balance: 0, rate: 1.12, volume: 0.76),
        ], gap: const Duration(milliseconds: 90));
        return;
      case GuidanceEventType.offRoute:
        await _playPattern([
          _CueStep(
            asset: _selectGuidanceAsset(
              headingErrorDeg: _guidanceHeadingErrorDeg,
              direction: _guidanceDirection,
            ),
            balance: 0,
            rate: 1.00,
            volume: 0.62,
            haptic: _CueHaptic.medium,
          ),
        ]);
        return;
      case GuidanceEventType.arrived:
        await _playPattern([
          _CueStep(asset: _waypointPassAsset, balance: 0, rate: 0.98, volume: 0.68),
          _CueStep(
            asset: _waypointPassAsset,
            balance: 0,
            rate: 1.08,
            volume: 0.82,
            haptic: _CueHaptic.medium,
          ),
          _CueStep(asset: _waypointPassAsset, balance: 0, rate: 1.18, volume: 0.94),
        ], gap: const Duration(milliseconds: 100));
        return;
      case GuidanceEventType.trackingUpdated:
        return;
    }
  }

  Future<void> _playPattern(
    List<_CueStep> pattern, {
    Duration gap = const Duration(milliseconds: 80),
  }) async {
    for (int i = 0; i < pattern.length; i++) {
      await _playStep(pattern[i]);
      if (i < pattern.length - 1) {
        await Future<void>.delayed(gap);
      }
    }
  }

  Future<void> _playStep(_CueStep step) async {
    try {
      await _eventPlayer.play(
        step.asset,
        mode: PlayerMode.lowLatency,
        volume: step.volume,
        balance: step.balance,
      );
      await _eventPlayer.setPlaybackRate(step.rate);
      await _emitHaptic(step.haptic);
    } catch (_) {}
  }

  Future<void> _scheduleNextGuidancePulse() async {
    if (!_guidanceToneActive) return;
    final severity = _guidanceSeverity ?? 0;
    await _playGuidancePulse(severity);
    if (!_guidanceToneActive) return;

    final intervalMs = _guidanceIntervalMs(
      headingErrorDeg: _guidanceHeadingErrorDeg,
      distanceToWaypointMeters: _distanceToWaypointMeters,
    );
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer(Duration(milliseconds: intervalMs), () {
      unawaited(_scheduleNextGuidancePulse());
    });
  }

  Future<void> _playGuidancePulse(double severity) async {
    final useChime = _guidanceHeadingErrorDeg < _chimeFocusThresholdDeg;
    final rate = useChime
        ? _lerpDouble(0.98, 1.04, severity)
        : _lerpDouble(0.92, 1.00, severity);
    final volume = useChime
        ? _lerpDouble(0.34, 0.60, severity)
        : _lerpDouble(0.40, 0.68, severity);

    final asset = _selectGuidanceAsset(
      headingErrorDeg: _guidanceHeadingErrorDeg,
      direction: _guidanceDirection,
    );

    try {
      await _offRoutePlayer.play(
        asset,
        mode: PlayerMode.lowLatency,
        volume: volume,
        balance: 0,
      );
      await _offRoutePlayer.setPlaybackRate(rate);
    } catch (_) {}
  }

  void _stopDirectionalGuidance() {
    _guidanceToneActive = false;
    _guidanceSeverity = null;
    _guidanceDirection = AudioCueDirection.center;
    _guidanceHeadingErrorDeg = 180;
    _distanceToWaypointMeters = _distanceTempoFarMeters;
    _guidanceTimer?.cancel();
    _guidanceTimer = null;
    unawaited(_offRoutePlayer.stop());
  }

  AssetSource _selectGuidanceAsset({
    required double headingErrorDeg,
    required AudioCueDirection direction,
  }) {
    final useChime = headingErrorDeg < (_chimeFocusThresholdDeg + 4);
    if (useChime) {
      return switch (direction) {
        AudioCueDirection.left => _offRouteChimeLeftAsset,
        AudioCueDirection.right => _offRouteChimeRightAsset,
        AudioCueDirection.center => _offRouteChimeCenterAsset,
      };
    }
    return switch (direction) {
      AudioCueDirection.left => _offRouteDrumLeftAsset,
      AudioCueDirection.right => _offRouteDrumRightAsset,
      AudioCueDirection.center => _offRouteDrumCenterAsset,
    };
  }

  int _guidanceIntervalMs({
    required double headingErrorDeg,
    required double distanceToWaypointMeters,
  }) {
    const minFrequencyHz = 0.5;
    const maxHeadingFrequencyHz = 2.0;
    const maxDistanceFrequencyHz = 3.4;
    final normalizedAngle = (headingErrorDeg.abs() / 180.0).clamp(0.0, 1.0);
    final headingFrequencyHz =
        minFrequencyHz + ((maxHeadingFrequencyHz - minFrequencyHz) * normalizedAngle);
    final normalizedDistance =
        ((_distanceTempoFarMeters - distanceToWaypointMeters) /
                (_distanceTempoFarMeters - _distanceTempoNearMeters))
            .clamp(0.0, 1.0);
    final distanceFrequencyHz =
        minFrequencyHz + ((maxDistanceFrequencyHz - minFrequencyHz) * normalizedDistance);
    final frequencyHz = math.max(headingFrequencyHz, distanceFrequencyHz);
    return (1000.0 / frequencyHz).round();
  }

  double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);

  Future<void> _emitHaptic(_CueHaptic haptic) async {
    switch (haptic) {
      case _CueHaptic.none:
        return;
      case _CueHaptic.light:
        await HapticFeedback.lightImpact();
        return;
      case _CueHaptic.medium:
        await HapticFeedback.mediumImpact();
        return;
      case _CueHaptic.heavy:
        await HapticFeedback.heavyImpact();
        return;
    }
  }
}

class _MethodChannelSpatialAudioRenderer implements _GuidanceAudioRenderer {
  final MethodChannel _channel = const MethodChannel(SpatialAudioChannelContract.methodChannel);
  bool _initialized = false;

  Future<bool> canUseSpatialAudio() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return false;
    final status = await getAudioOutputStatus();
    return status.supportsSpatial;
  }

  Future<AudioOutputStatus> getAudioOutputStatus() async {
    if (!(Platform.isIOS || Platform.isAndroid)) {
      return const AudioOutputStatus.unknown();
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        SpatialAudioChannelContract.getCapabilitiesMethod,
      );
      return AudioOutputStatus(
        supportsSpatial: result?[SpatialAudioChannelContract.supportsSpatialKey] == true,
        supportsStereoPan: result?[SpatialAudioChannelContract.supportsStereoPanKey] == true,
        isMonoAudioEnabled:
            result?[SpatialAudioChannelContract.isMonoAudioEnabledKey] == true,
        hasHeadphonesConnected:
            result?[SpatialAudioChannelContract.hasHeadphonesConnectedKey] == true,
      );
    } catch (_) {
      return const AudioOutputStatus.unknown();
    }
  }

  @override
  Future<void> init() async {
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod<void>(SpatialAudioChannelContract.stopOffRouteAlertMethod);
    } catch (_) {}
    _initialized = false;
  }

  @override
  Future<void> primeDirectionalGuidance() async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod<void>(SpatialAudioChannelContract.primeOffRouteLoopMethod);
    } catch (_) {}
  }

  @override
  Future<void> playCue(GuidanceEventType type) async {
    if (!_initialized) return;
    try {
      await _channel.invokeMethod<void>(
        SpatialAudioChannelContract.playCueMethod,
        {SpatialAudioChannelContract.cueTypeKey: type.name},
      );
    } catch (_) {}
  }

  @override
  void updateDirectionalGuidance({
    required bool isActive,
    required double severity,
    required AudioCueDirection direction,
    required double headingErrorDeg,
    required double relativeAngleDeg,
    required double sourceDistanceMeters,
    required double distanceToWaypointMeters,
  }) {
    if (!_initialized) return;
    if (!isActive) {
      unawaited(_channel.invokeMethod<void>(SpatialAudioChannelContract.stopOffRouteAlertMethod));
      return;
    }
    unawaited(
      _channel.invokeMethod<void>(
        SpatialAudioChannelContract.updateOffRouteAlertMethod,
        {
          SpatialAudioChannelContract.sideKey: direction.name,
          SpatialAudioChannelContract.severityKey: severity,
          SpatialAudioChannelContract.headingErrorDegKey: headingErrorDeg,
          SpatialAudioChannelContract.relativeAngleDegKey: relativeAngleDeg,
          SpatialAudioChannelContract.sourceDistanceMetersKey: sourceDistanceMeters,
          SpatialAudioChannelContract.distanceToWaypointMetersKey: distanceToWaypointMeters,
        },
      ),
    );
  }
}

class _CueStep {
  final AssetSource asset;
  final double balance;
  final double rate;
  final double volume;
  final _CueHaptic haptic;

  const _CueStep({
    required this.asset,
    required this.balance,
    required this.rate,
    required this.volume,
    this.haptic = _CueHaptic.none,
  });
}

enum _CueHaptic { none, light, medium, heavy }

class _DirectionalGuidanceState {
  final bool isActive;
  final double severity;
  final AudioCueDirection direction;
  final double headingErrorDeg;
  final double relativeAngleDeg;
  final double sourceDistanceMeters;
  final double distanceToWaypointMeters;

  const _DirectionalGuidanceState({
    required this.isActive,
    required this.severity,
    required this.direction,
    required this.headingErrorDeg,
    required this.relativeAngleDeg,
    required this.sourceDistanceMeters,
    required this.distanceToWaypointMeters,
  });

  const _DirectionalGuidanceState.inactive()
      : isActive = false,
        severity = 0,
        direction = AudioCueDirection.center,
        headingErrorDeg = 180,
        relativeAngleDeg = 0,
        sourceDistanceMeters = 6,
        distanceToWaypointMeters = 6;
}
