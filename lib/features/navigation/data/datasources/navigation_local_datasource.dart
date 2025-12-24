import 'package:geolocator/geolocator.dart';
import '../../../../core/error/exceptions.dart';
import '../models/location_model.dart';

abstract class NavigationLocalDataSource {
  Future<LocationModel> getCurrentLocation();
  Stream<LocationModel> watchLocation();
}

class NavigationLocalDataSourceImpl implements NavigationLocalDataSource {
  @override
  Future<LocationModel> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const PermissionException('Location services are disabled');
      }

      // Check permissions
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (e is PermissionException) rethrow;
      throw AppException('Failed to get current location: $e');
    }
  }

  @override
  Stream<LocationModel> watchLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).map(
      (position) => LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      ),
    );
  }
}
