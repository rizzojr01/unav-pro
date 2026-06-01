import 'dart:typed_data';

import '../entities/ar_pose.dart';

/// JPEG bytes and the ARFrame pose captured atomically from the same frame.
class ArCaptureWithPose {
  final Uint8List jpegBytes;
  final ArPose pose;

  const ArCaptureWithPose({required this.jpegBytes, required this.pose});
}

abstract class ArPoseRepository {
  Stream<ArPose> watchPose();
  Future<void> start();
  Future<void> stop();
  Future<Uint8List> captureCurrentFrame();

  /// Atomically captures a JPEG and the pose from the SAME ARFrame.
  /// Use this when accurate alignment between an image and the AR pose is
  /// required (e.g. recording the capture pose passed as navigation origin).
  Future<ArCaptureWithPose> captureCurrentFrameWithPose();

  Future<double?> getCurrentHeading();
  Future<void> clearOverlay();
  Future<void> updateOverlay({
    required List<List<double>> pathPoints,
    required List<List<double>> activePathPoints,
    required List<List<double>> futurePathPoints,
    required List<double> nextWaypoint,
    required List<double> destination,
    bool waypointPulseActive = true,
  });
}
