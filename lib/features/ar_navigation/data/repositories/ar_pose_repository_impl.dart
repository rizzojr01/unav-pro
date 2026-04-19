import 'package:flutter/services.dart';
import '../../domain/entities/ar_pose.dart';
import '../../domain/repositories/ar_pose_repository.dart';
import '../datasources/ar_channel_contract.dart';

class ArPoseRepositoryImpl implements ArPoseRepository {
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final String _backend;

  ArPoseRepositoryImpl({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    String backend =
        'arkit', // Default to arkit, can be changed based on platform
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel(ArChannelContract.methodChannel),
       _eventChannel =
           eventChannel ?? const EventChannel(ArChannelContract.eventChannel),
       _backend = backend;

  @override
  Future<void> start() async {
    await _methodChannel.invokeMethod<void>(
      ArChannelContract.startSessionMethod,
      {ArChannelContract.backendKey: _backend},
    );
  }

  @override
  Future<void> stop() async {
    await _methodChannel.invokeMethod<void>(
      ArChannelContract.stopSessionMethod,
      {ArChannelContract.backendKey: _backend},
    );
  }

  @override
  Future<double?> getCurrentHeading() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'getCurrentHeading',
        {ArChannelContract.backendKey: _backend},
      );
      if (result != null && result['heading'] != null) {
        return (result['heading'] as num).toDouble();
      }
    } catch (e) {
      // Log the specific error for debugging
      print('AR Repository: getCurrentHeading failed with $e');
    }

    // Fallback: try capturing frame info
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        ArChannelContract.captureCurrentFrameMethod,
        {ArChannelContract.backendKey: _backend},
      );
      if (result != null && result[ArChannelContract.headingKey] != null) {
        return (result[ArChannelContract.headingKey] as num).toDouble();
      }
    } catch (e) {
      print('AR Repository: captureCurrentFrame fallback failed with $e');
    }
    return null;
  }

  @override
  Future<void> updateOverlay({
    required List<List<double>> pathPoints,
    required List<List<double>> activePathPoints,
    required List<List<double>> futurePathPoints,
    required List<double> nextWaypoint,
    required List<double> destination,
    bool waypointPulseActive = true,
  }) async {
    await _methodChannel
        .invokeMethod<void>(ArChannelContract.updateOverlayMethod, {
          ArChannelContract.backendKey: _backend,
          ArChannelContract.pathPointsKey: pathPoints,
          ArChannelContract.activePathPointsKey: activePathPoints,
          ArChannelContract.futurePathPointsKey: futurePathPoints,
          ArChannelContract.nextWaypointKey: nextWaypoint,
          ArChannelContract.destinationKey: destination,
          ArChannelContract.waypointPulseActiveKey: waypointPulseActive,
        });
  }

  @override
  Stream<ArPose> watchPose() {
    return _eventChannel
        .receiveBroadcastStream({ArChannelContract.backendKey: _backend})
        .map((event) {
          final data = Map<String, dynamic>.from(event as Map);
          return ArPose(
            x: (data[ArChannelContract.xKey] as num?)?.toDouble() ?? 0,
            y: (data[ArChannelContract.yKey] as num?)?.toDouble() ?? 0,
            z: (data[ArChannelContract.zKey] as num?)?.toDouble() ?? 0,
            heading:
                (data[ArChannelContract.headingKey] as num?)?.toDouble() ?? 0,
            confidence:
                (data[ArChannelContract.confidenceKey] as num?)?.toDouble() ??
                1,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (data[ArChannelContract.timestampKey] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
            ),
          );
        });
  }
}
