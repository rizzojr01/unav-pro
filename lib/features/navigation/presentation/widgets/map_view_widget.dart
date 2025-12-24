import 'package:flutter/material.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';

class MapViewWidget extends StatelessWidget {
  final LocationEntity currentLocation;
  final RouteEntity route;
  final bool isNavigating;

  const MapViewWidget({
    super.key,
    required this.currentLocation,
    required this.route,
    this.isNavigating = false,
  });

  @override
  Widget build(BuildContext context) {
    // This is a placeholder for the actual map implementation
    // In a real app, you would use Google Maps, Mapbox, or another map provider
    return Container(
      color: Colors.grey[200],
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 100, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Map View Placeholder',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current: ${currentLocation.latitude.toStringAsFixed(4)}, '
                  '${currentLocation.longitude.toStringAsFixed(4)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Destination: ${route.destination.latitude.toStringAsFixed(4)}, '
                  '${route.destination.longitude.toStringAsFixed(4)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (isNavigating)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.navigation, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Navigation Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
