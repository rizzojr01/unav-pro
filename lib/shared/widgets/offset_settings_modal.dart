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
          child: _ArHeadingOffsetCompact(locationConfig: locationConfig),
        ),
      ),
    ),
  );
}

class _ArHeadingOffsetCompact extends StatelessWidget {
  final LocationConfigService locationConfig;

  const _ArHeadingOffsetCompact({required this.locationConfig});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: locationConfig.arHeadingOffsetDegNotifier,
      builder: (context, currentValue, _) {
        return Column(
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
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  tooltip: 'Reset',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () =>
                      locationConfig.setArHeadingOffsetDeg(0),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                    ),
                    child: Slider(
                      value: currentValue.clamp(-180.0, 180.0),
                      min: -180,
                      max: 180,
                      divisions: 720,
                      onChanged: (v) =>
                          locationConfig.setArHeadingOffsetDeg(v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${currentValue.toStringAsFixed(1)}°',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
