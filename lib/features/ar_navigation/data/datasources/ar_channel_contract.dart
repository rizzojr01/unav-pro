class ArChannelContract {
  static const String methodChannel = 'unav/tracking/ar_method';
  static const String eventChannel = 'unav/tracking/ar_pose_stream';

  static const String startSessionMethod = 'startSession';
  static const String stopSessionMethod = 'stopSession';
  static const String getCapabilitiesMethod = 'getCapabilities';
  static const String captureCurrentFrameMethod = 'captureCurrentFrame';
  static const String updateOverlayMethod = 'updateOverlay';
  static const String clearOverlayMethod = 'clearOverlay';
  static const String previewViewType = 'unav/tracking/ar_preview_view';

  static const String backendKey = 'backend';
  static const String xKey = 'x';
  static const String yKey = 'y';
  static const String zKey = 'z';
  static const String headingKey = 'heading';
  static const String confidenceKey = 'confidence';
  static const String timestampKey = 'timestampMillis';
  static const String isSupportedKey = 'isSupported';
  static const String worldXKey = 'worldX';
  static const String worldYKey = 'worldY';
  static const String worldZKey = 'worldZ';
  static const String gravityXKey = 'gravityX';
  static const String gravityYKey = 'gravityY';
  static const String gravityZKey = 'gravityZ';
  static const String interfaceRotationDegKey = 'interfaceRotationDeg';
  static const String pathPointsKey = 'pathPoints';
  static const String activePathPointsKey = 'activePathPoints';
  static const String futurePathPointsKey = 'futurePathPoints';
  static const String nextWaypointKey = 'nextWaypoint';
  static const String destinationKey = 'destination';
  static const String waypointPulsePeriodSecKey = 'waypointPulsePeriodSec';
  static const String waypointPulseActiveKey = 'waypointPulseActive';
}
