import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final String title;
  final VoidCallback? onBack;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.98),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: theme.colorScheme.onSurface,
                          size: 18,
                        ),
                        onPressed: onBack,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStep(context, 1, 'DESTINATION', currentStep >= 1),
                  _buildLine(context, currentStep >= 2),
                  _buildStep(context, 2, 'CAPTURE', currentStep >= 2),
                  _buildLine(context, currentStep >= 3),
                  _buildStep(context, 3, 'NAVIGATE', currentStep >= 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    int step,
    String label,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? theme.primaryColor : theme.colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: (isActive && isDark)
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isActive
                ? (currentStep > step
                      ? Icon(
                          Icons.check,
                          color: theme.colorScheme.onPrimary,
                          size: 14,
                        )
                      : Text(
                          step.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ))
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? theme.primaryColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(BuildContext context, bool isActive) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 32,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? theme.primaryColor : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
