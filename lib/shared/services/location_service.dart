import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/error/exceptions.dart';

class LocationService {
  /// Get current location using Geolocator (real implementation)
  /// Falls back to mock data if permissions are denied
  Future<Position> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _getMockLocation();
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _getMockLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _getMockLocation();
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      // Fall back to mock location on any error
      return _getMockLocation();
    }
  }

  /// Get mock location from JSON file
  Future<Position> _getMockLocation() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/mock_data/current_location.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      return Position(
        latitude: jsonData['latitude'] as double,
        longitude: jsonData['longitude'] as double,
        timestamp: DateTime.parse(jsonData['timestamp'] as String),
        accuracy: jsonData['accuracy'] as double,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    } catch (e) {
      throw CacheException('Failed to load mock location data');
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
  /// Returns mock address for now
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // TODO: Implement reverse geocoding when backend is ready
    // For now, return a formatted string
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
