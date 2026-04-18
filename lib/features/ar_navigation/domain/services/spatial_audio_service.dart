import 'package:flutter/services.dart';
import '../../data/datasources/spatial_audio_channel_contract.dart';

class SpatialAudioService {
  final MethodChannel _methodChannel;

  SpatialAudioService({MethodChannel? methodChannel})
    : _methodChannel =
          methodChannel ??
          const MethodChannel(SpatialAudioChannelContract.methodChannel);

  Future<Map<String, dynamic>> getCapabilities() async {
    try {
      final Map<dynamic, dynamic>? result = await _methodChannel
          .invokeMapMethod(SpatialAudioChannelContract.getCapabilitiesMethod);
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
  }

  Future<void> playCue(String cueType) async {
    try {
      await _methodChannel.invokeMethod(
        SpatialAudioChannelContract.playCueMethod,
        {SpatialAudioChannelContract.cueTypeKey: cueType},
      );
    } on PlatformException catch (e) {
      print('Failed to play cue: ${e.message}');
    }
  }

  Future<void> playStereoAsset(
    String assetPath, {
    double volume = 0.25,
    double rate = 1.0,
  }) async {
    try {
      await _methodChannel
          .invokeMethod(SpatialAudioChannelContract.playStereoAssetMethod, {
            SpatialAudioChannelContract.assetPathKey: assetPath,
            SpatialAudioChannelContract.volumeKey: volume,
            SpatialAudioChannelContract.rateKey: rate,
          });
    } on PlatformException catch (e) {
      print('Failed to play stereo asset: ${e.message}');
    }
  }

  Future<void> primeOffRouteLoop() async {
    try {
      await _methodChannel.invokeMethod(
        SpatialAudioChannelContract.primeOffRouteLoopMethod,
      );
    } on PlatformException catch (e) {
      print('Failed to prime off-route loop: ${e.message}');
    }
  }

  Future<void> updateOffRouteAlert({
    required String side,
    required double severity,
    required double headingErrorDeg,
    required double relativeAngleDeg,
    required double sourceDistanceMeters,
    required double distanceToWaypointMeters,
  }) async {
    try {
      await _methodChannel
          .invokeMethod(SpatialAudioChannelContract.updateOffRouteAlertMethod, {
            SpatialAudioChannelContract.sideKey: side,
            SpatialAudioChannelContract.severityKey: severity,
            SpatialAudioChannelContract.headingErrorDegKey: headingErrorDeg,
            SpatialAudioChannelContract.relativeAngleDegKey: relativeAngleDeg,
            SpatialAudioChannelContract.sourceDistanceMetersKey:
                sourceDistanceMeters,
            SpatialAudioChannelContract.distanceToWaypointMetersKey:
                distanceToWaypointMeters,
          });
    } on PlatformException catch (e) {
      print('Failed to update off-route alert: ${e.message}');
    }
  }

  Future<void> stopOffRouteAlert() async {
    try {
      await _methodChannel.invokeMethod(
        SpatialAudioChannelContract.stopOffRouteAlertMethod,
      );
    } on PlatformException catch (e) {
      print('Failed to stop off-route alert: ${e.message}');
    }
  }
}
