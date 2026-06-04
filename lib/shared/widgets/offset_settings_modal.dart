import 'package:flutter/material.dart';
import '../../injection.dart';
import '../services/location_config_service.dart';

void showOffsetSettingsModal(BuildContext context) {
  final theme = Theme.of(context);
  final locationConfig = getIt<LocationConfigService>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.transparent,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              _RotationRow(locationConfig: locationConfig),
              const SizedBox(height: 6),
              _PositionOffsetRow(locationConfig: locationConfig),
              const SizedBox(height: 6),
              _SnapToRouteRow(locationConfig: locationConfig),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RotationRow extends StatelessWidget {
  final LocationConfigService locationConfig;

  const _RotationRow({required this.locationConfig});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: locationConfig.arHeadingOffsetDegNotifier,
      builder: (context, currentValue, _) {
        final clamped = currentValue.clamp(-10.0, 10.0);
        return Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Reset rotation',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => locationConfig.setArHeadingOffsetDeg(0),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.rotate_right, size: 16),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: clamped,
                  min: -10,
                  max: 10,
                  divisions: 40, // 0.5° step
                  onChanged: (v) {
                    final snapped = (v * 2).round() / 2.0;
                    locationConfig.setArHeadingOffsetDeg(snapped);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${clamped.toStringAsFixed(1)}°',
                textAlign: TextAlign.right,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PositionOffsetRow extends StatelessWidget {
  final LocationConfigService locationConfig;

  const _PositionOffsetRow({required this.locationConfig});

  static const double _step = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: locationConfig.offsetInMetersNotifier,
      builder: (context, currentValue, _) {
        return Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Reset offset',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => locationConfig.setOffsetInMeters(0),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.height, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Position Offset',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.remove,
              onTap: () =>
                  locationConfig.setOffsetInMeters(currentValue - _step),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${currentValue.toStringAsFixed(1)} m',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: () =>
                  locationConfig.setOffsetInMeters(currentValue + _step),
            ),
          ],
        );
      },
    );
  }
}

class _SnapToRouteRow extends StatelessWidget {
  final LocationConfigService locationConfig;

  const _SnapToRouteRow({required this.locationConfig});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: locationConfig.snapToRouteNotifier,
      builder: (context, value, _) {
        return Row(
          children: [
            const SizedBox(width: 36),
            const Icon(Icons.route, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Snap to route',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: (v) => locationConfig.setSnapToRoute(v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.primary),
      ),
    );
  }
}
