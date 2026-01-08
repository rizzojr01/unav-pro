import 'package:flutter/material.dart';
import 'custom_button.dart';

class CustomErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData icon;

  const CustomErrorView({
    super.key,
    this.title = 'ERROR DETECTED',
    required this.message,
    this.onRetry,
    this.retryText = 'RETRY',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 32),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 48),
              CustomButton(
                text: retryText,
                onPressed: onRetry,
                width: 200,
                backgroundColor: theme.colorScheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
