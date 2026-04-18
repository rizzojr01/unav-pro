class SpatialAudioChannelContract {
  static const String methodChannel = 'unav/audio/spatial_method';

  static const String getCapabilitiesMethod = 'getCapabilities';
  static const String playCueMethod = 'playCue';
  static const String playStereoAssetMethod = 'playStereoAsset';
  static const String primeOffRouteLoopMethod = 'primeOffRouteLoop';
  static const String updateOffRouteAlertMethod = 'updateOffRouteAlert';
  static const String stopOffRouteAlertMethod = 'stopOffRouteAlert';

  static const String supportsSpatialKey = 'supportsSpatial';
  static const String supportsStereoPanKey = 'supportsStereoPan';
  static const String isMonoAudioEnabledKey = 'isMonoAudioEnabled';
  static const String hasHeadphonesConnectedKey = 'hasHeadphonesConnected';
  static const String cueTypeKey = 'cueType';
  static const String assetPathKey = 'assetPath';
  static const String sideKey = 'side';
  static const String severityKey = 'severity';
  static const String headingErrorDegKey = 'headingErrorDeg';
  static const String relativeAngleDegKey = 'relativeAngleDeg';
  static const String sourceDistanceMetersKey = 'sourceDistanceMeters';
  static const String distanceToWaypointMetersKey = 'distanceToWaypointMeters';
  static const String volumeKey = 'volume';
  static const String rateKey = 'rate';

  static const String cueTypeArrived = 'arrived';
  static const String cueTypeTurnLeft = 'turnLeft';
  static const String cueTypeTurnRight = 'turnRight';
  static const String cueTypeOffRoute = 'offRoute';
}
