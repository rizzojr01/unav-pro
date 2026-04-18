import '../entities/ar_pose.dart';

abstract class ArPoseRepository {
  Stream<ArPose> watchPose();
  Future<void> start();
  Future<void> stop();
  Future<void> updateOverlay({
    required List<List<double>> pathPoints,
    required List<List<double>> activePathPoints,
    required List<List<double>> futurePathPoints,
    required List<double> nextWaypoint,
    required List<double> destination,
    bool waypointPulseActive = true,
  });
}
