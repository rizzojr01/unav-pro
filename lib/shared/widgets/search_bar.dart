import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomSearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const CustomSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.onTap,
    this.onChanged,
    this.readOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.secondary
              : theme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: readOnly
                  ? Text(
                      hintText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                        fontSize: 15,
                      ),
                    )
                  : TextField(
                      onChanged: onChanged,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
