import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = theme.colorScheme.tertiary;
        icon = Icons.check_circle;
        break;
      case SnackBarType.error:
        backgroundColor = theme.colorScheme.error;
        icon = Icons.error;
        break;
      case SnackBarType.warning:
        backgroundColor = theme.colorScheme.tertiaryContainer;
        icon = Icons.warning;
        break;
      case SnackBarType.info:
        backgroundColor = theme.colorScheme.primary;
        icon = Icons.info;
        break;
    }

    // Determine text color based on background luminance
    final onColor = backgroundColor.computeLuminance() > 0.5
        ? theme.colorScheme.onSurface
        : theme.colorScheme.surface;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: onColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: onColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }
}
