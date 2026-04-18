import 'package:flutter/material.dart';
import '../../domain/services/path_tracking_service.dart';

class ArGuidanceBanner extends StatelessWidget {
  final ArTrackingState state;
  final double remainingDistancePx;
  final double distanceToNextWaypointPx;
  final String? message;

  const ArGuidanceBanner({
    super.key,
    required this.state,
    required this.remainingDistancePx,
    required this.distanceToNextWaypointPx,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${message ?? ""} • Rem: ${remainingDistancePx.toStringAsFixed(0)} • Next: ${distanceToNextWaypointPx.toStringAsFixed(0)}',
            style: theme.textTheme.labelSmall!.copyWith(
              color: Colors.white,
              fontSize: 9,
              shadows: [
                const Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForState(ArTrackingState state) {
    switch (state) {
      case ArTrackingState.offRoute:
        return const Color(0xFFD32F2F);
      case ArTrackingState.arrived:
        return const Color(0xFF388E3C);
      case ArTrackingState.localizing:
        return const Color(0xFF607D8B);
      case ArTrackingState.idle:
      case ArTrackingState.tracking:
        return Colors.black;
    }
  }

  String _titleForState(ArTrackingState state) {
    switch (state) {
      case ArTrackingState.offRoute:
        return 'OFF ROUTE';
      case ArTrackingState.arrived:
        return 'ARRIVED';
      case ArTrackingState.localizing:
        return 'LOCALIZING...';
      case ArTrackingState.idle:
        return 'READY';
      case ArTrackingState.tracking:
        return 'FOLLOW PATH';
    }
  }
}
