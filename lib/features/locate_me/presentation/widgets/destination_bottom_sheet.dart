import 'package:flutter/material.dart';

import '../../../../injection.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../destination/domain/entities/destination_entity.dart';

class DestinationBottomSheet extends StatelessWidget {
  final DestinationEntity destination;
  final VoidCallback onNavigate;

  const DestinationBottomSheet({
    super.key,
    required this.destination,
    required this.onNavigate,
  });

  /// Format floor name from "6_floor" format to "Floor 6"
  String _formatFloorName(String floor) {
    final floorNumber = floor.replaceAll(RegExp(r'[^0-9]'), '');
    if (floorNumber.isNotEmpty) {
      return 'Floor $floorNumber';
    }
    return floor.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationConfigService = getIt<LocationConfigService>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getDestinationIcon(destination.name),
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatFloorName(
                                  destination.floor?.isNotEmpty == true
                                      ? destination.floor!
                                      : locationConfigService.floor,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        Icons.straighten,
                        'Distance',
                        _calculateDistance(destination),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        Icons.access_time,
                        'Est. Time',
                        _calculateTime(destination),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Navigate button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text(
                      'Navigate Me Here',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _calculateDistance(DestinationEntity destination) {
    if (destination.x.isNaN || destination.x.isInfinite) return 'Unknown';
    // Mock calculation - in real app, calculate from user position
    return '${(destination.x / 100).toStringAsFixed(0)} m';
  }

  String _calculateTime(DestinationEntity destination) {
    if (destination.x.isNaN || destination.x.isInfinite) return '--';
    // Mock calculation - in real app, calculate based on distance
    final meters = destination.x / 100;
    final minutes = (meters / 50).ceil(); // Assuming 50m/min walking speed
    return '$minutes min';
  }

  IconData _getDestinationIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('elevator')) return Icons.elevator;
    if (lowerName.contains('restroom') || lowerName.contains('bathroom')) {
      return Icons.wc;
    }
    if (lowerName.contains('pantry') || lowerName.contains('kitchen')) {
      return Icons.kitchen;
    }
    if (lowerName.contains('office')) return Icons.business;
    if (lowerName.contains('reception')) return Icons.desk;
    if (lowerName.contains('board') || lowerName.contains('meeting')) {
      return Icons.meeting_room;
    }
    if (lowerName.contains('men')) return Icons.male;
    if (lowerName.contains('women')) return Icons.female;
    if (lowerName.contains('ada') || lowerName.contains('accessible')) {
      return Icons.accessible;
    }
    if (lowerName.contains('water')) return Icons.water_drop;
    return Icons.place;
  }
}
