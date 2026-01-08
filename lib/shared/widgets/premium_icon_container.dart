import 'package:flutter/material.dart';

class PremiumIconContainer extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? iconColor;
  final bool usePulse;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const PremiumIconContainer({
    super.key,
    required this.icon,
    this.size = 100,
    this.iconSize = 48,
    this.color,
    this.iconColor,
    this.usePulse = false,
    this.borderRadius,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveIconColor =
        iconColor ??
        (isCircle ? theme.colorScheme.primary : theme.colorScheme.onPrimary);
    final r = isCircle
        ? BorderRadius.circular(size / 2)
        : (borderRadius ?? BorderRadius.circular(size * 0.32));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base Gradient / Solid
            Container(
              decoration: BoxDecoration(
                color: isCircle ? theme.colorScheme.surface : null,
                gradient: isCircle
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          effectiveColor,
                          Color.lerp(effectiveColor, Colors.black, 0.1)!,
                        ],
                      ),
              ),
            ),
            if (!isCircle) ...[
              // Inner Shine Light
              Positioned(
                top: -size * 0.4,
                left: -size * 0.4,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Reflection
              Positioned(
                bottom: -size * 0.5,
                right: -size * 0.5,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // Subtle Border
            Container(
              decoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(
                  color: isCircle
                      ? effectiveColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
            Icon(
              icon,
              size: iconSize,
              color: effectiveIconColor,
              shadows: isCircle
                  ? null
                  : [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
