import 'package:flutter/material.dart';

/// A combined widget for map controls (Search, Reset)
class MapControls extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onReset;
  final VoidCallback? onToggleMode;
  final bool isAutoRotate;
  final IconData? resetIcon;
  final double right;
  final double bottom;

  const MapControls({
    super.key,
    required this.onSearch,
    required this.onReset,
    this.onToggleMode,
    this.isAutoRotate = false,
    this.resetIcon,
    this.right = 16,
    this.bottom = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapControlButton(
            icon: Icons.search,
            onPressed: onSearch,
            tooltip: 'Search destinations',
          ),
          const SizedBox(height: 12),
          if (onToggleMode != null) ...[
            MapControlButton(
              icon: isAutoRotate ? Icons.explore : Icons.explore_outlined,
              onPressed: onToggleMode!,
              tooltip: isAutoRotate ? 'Heading-Up Mode' : 'North-Up Mode',
            ),
            const SizedBox(height: 12),
          ],
          MapControlButton(
            icon: resetIcon ?? Icons.my_location,
            onPressed: onReset,
            tooltip: 'Reset view',
          ),
        ],
      ),
    );
  }
}

/// A standalone map control button with premium styling
class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const MapControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
        ),
      ),
    );
  }
}
