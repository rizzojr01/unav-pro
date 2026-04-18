import 'dart:math' as math;
import 'package:flutter/material.dart';

class UserPositionMarker extends StatelessWidget {
  final double size;
  final double? heading;
  final Color? primaryColor;
  final Color? iconColor;
  final bool showPulse;
  final bool isCheckpoint;

  const UserPositionMarker({
    super.key,
    this.size = 14.0,
    this.heading,
    this.primaryColor,
    this.iconColor,
    this.showPulse = true,
    this.isCheckpoint = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = primaryColor ?? Colors.green;
    final fgColor = iconColor ?? Colors.white;

    // Convert degrees to radians for rotation
    final orientationDegrees = heading ?? 0.0;
    final rotationRadians =
        orientationDegrees.isNaN || orientationDegrees.isInfinite
        ? 0.0
        : orientationDegrees * (math.pi / 180);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          if (showPulse)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor.withValues(alpha: 0.2),
              ),
            ),

          // Main marker body
          Container(
            width: isCheckpoint ? size * 0.5 : size * 0.75,
            height: isCheckpoint ? size * 0.5 : size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCheckpoint ? Colors.white : bgColor,
              border: Border.all(
                color: isCheckpoint ? bgColor : Colors.white,
                width: isCheckpoint ? 1.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isCheckpoint ? bgColor : Colors.black).withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isCheckpoint
                ? Center(
                    child: Container(
                      width: size * 0.2,
                      height: size * 0.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor,
                        boxShadow: [
                          BoxShadow(
                            color: bgColor.withValues(alpha: 0.4),
                            blurRadius: 2,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  )
                : Transform.rotate(
                    angle: rotationRadians,
                    child: Icon(
                      Icons.navigation,
                      size: size * 0.4,
                      color: fgColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Destination marker with flag icon - refined pin style
class DestinationFlagMarker extends StatelessWidget {
  final double size;
  final Color? flagColor;
  final Color? iconColor;
  final String? label;
  final VoidCallback? onTap;

  const DestinationFlagMarker({
    super.key,
    this.size = 24.0,
    this.flagColor,
    this.iconColor,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = flagColor ?? const Color(0xFFEA4335);
    final fgColor = iconColor ?? Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor.withValues(alpha: 0.15),
            ),
          ),
          // Main Pin
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgColor, bgColor.withValues(alpha: 0.8)],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.flag_rounded, size: size * 0.45, color: fgColor),
          ),
        ],
      ),
    );
  }
}

/// Simple destination marker (circular with icon) for POIs on locate me map
class DestinationMarker extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconData icon;
  final VoidCallback? onTap;

  const DestinationMarker({
    super.key,
    this.size = 28.0,
    this.backgroundColor,
    this.iconColor,
    this.icon = Icons.place,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(0xFFEA4335);
    final isGeneralIcon = icon == Icons.place;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: isGeneralIcon
            ? null
            : BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
        color: isGeneralIcon ? Colors.transparent : null,
        child: Icon(
          icon,
          color: isGeneralIcon ? bgColor : Colors.white,
          size: isGeneralIcon ? size : size * 0.6,
        ),
      ),
    );
  }

  /// Get appropriate icon based on destination name
  static IconData getIconForDestination(String name) {
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
    return Icons.place;
  }
}
