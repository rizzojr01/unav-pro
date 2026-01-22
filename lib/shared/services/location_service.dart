import 'package:geolocator/geolocator.dart';
import '../../../core/error/exceptions.dart';

class LocationService {
  /// Get current location using Geolocator (real implementation)
  Future<Position> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const PermissionException('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw const PermissionException('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw const PermissionException(
          'Location permissions are permanently denied',
        );
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (e is PermissionException) {
        rethrow;
      }
      throw CacheException('Failed to get current location: ${e.toString()}');
    }
  }

  /// Watch location updates (stream)
  Stream<Position> watchLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Get address from coordinates (reverse geocoding)
  /// Returns formatted coordinates for now
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // TODO: Implement reverse geocoding when backend is ready
    // For now, return a formatted string
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
