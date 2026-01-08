import 'package:flutter/material.dart';

class CustomLoadingView extends StatelessWidget {
  final String message;
  final Color? color;

  const CustomLoadingView({super.key, this.message = 'LOADING...', this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: effectiveColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            message.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
