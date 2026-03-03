import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/bloc/location_settings_bloc.dart';
import '../presentation/bloc/location_settings_event.dart';
import '../presentation/bloc/location_settings_state.dart';

/// Reusable widget that provides GPS and Wi-Fi auto-detection buttons
/// along with a "Save Wi-Fi Mapping" option.
///
/// Place this wherever the place/building selectors are shown — it listens
/// to the [LocationSettingsBloc] for status feedback.
class AutoDetectLocationWidget extends StatelessWidget {
  const AutoDetectLocationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LocationSettingsBloc, LocationSettingsState>(
      listenWhen: (prev, curr) {
        if (prev is LocationSettingsLoaded && curr is LocationSettingsLoaded) {
          return prev.autoDetectStatus != curr.autoDetectStatus;
        }
        return false;
      },
      listener: (context, state) {
        if (state is! LocationSettingsLoaded) return;
        final message = state.autoDetectMessage;
        if (message == null) return;

        final isSuccess = state.autoDetectStatus == AutoDetectStatus.detected;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: isSuccess
                ? Colors.green.shade700
                : Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: Duration(seconds: isSuccess ? 3 : 5),
          ),
        );
      },
      builder: (context, state) {
        if (state is! LocationSettingsLoaded) {
          return const SizedBox.shrink();
        }

        final isDetecting =
            state.autoDetectStatus == AutoDetectStatus.detecting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'AUTO DETECT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
              ),
            ),

            // GPS + Wi-Fi buttons row
            Row(
              children: [
                Expanded(
                  child: _AutoDetectButton(
                    icon: Icons.gps_fixed_rounded,
                    label: 'GPS',
                    isLoading: isDetecting,
                    onPressed: isDetecting
                        ? null
                        : () => context
                            .read<LocationSettingsBloc>()
                            .add(const AutoDetectByGpsEvent()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AutoDetectButton(
                    icon: Icons.wifi_rounded,
                    label: 'Wi-Fi',
                    isLoading: isDetecting,
                    onPressed: isDetecting
                        ? null
                        : () => context
                            .read<LocationSettingsBloc>()
                            .add(const AutoDetectByWifiEvent()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Save mapping buttons row
            Row(
              children: [
                Expanded(
                  child: _SaveMappingButton(
                    icon: Icons.gps_fixed_rounded,
                    label: 'Save GPS',
                    isDetecting: isDetecting,
                    onPressed: () => context
                        .read<LocationSettingsBloc>()
                        .add(const SaveGpsMappingEvent()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SaveMappingButton(
                    icon: Icons.wifi_rounded,
                    label: 'Save Wi-Fi',
                    isDetecting: isDetecting,
                    onPressed: () => context
                        .read<LocationSettingsBloc>()
                        .add(const SaveWifiMappingEvent()),
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

class _AutoDetectButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _AutoDetectButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveMappingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDetecting;
  final VoidCallback onPressed;

  const _SaveMappingButton({
    required this.icon,
    required this.label,
    required this.isDetecting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.icon(
      onPressed: isDetecting ? null : onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: isDetecting
            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDetecting
              ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

