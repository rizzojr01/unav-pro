import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../theme_bloc.dart';
import '../theme_palette.dart';
import '../app_theme.dart';

class ColorCustomizer extends StatelessWidget {
  const ColorCustomizer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ThemeBloc>().state;
    final currentScheme = state.palette.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'COLOR SCHEMES'),
        const SizedBox(height: 16),
        _buildCurrentSchemePreview(context, currentScheme),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'AVAILABLE THEMES'),
        const SizedBox(height: 12),
        _buildSchemeGrid(context, currentScheme),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildCurrentSchemePreview(BuildContext context, FlexScheme scheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get the color scheme for preview
    final previewScheme = isDark
        ? FlexColorScheme.dark(scheme: scheme).toScheme
        : FlexColorScheme.light(scheme: scheme).toScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Theme',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTheme.getSchemeName(scheme),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildColorSwatch('Primary', previewScheme.primary),
              const SizedBox(width: 12),
              _buildColorSwatch('Secondary', previewScheme.secondary),
              const SizedBox(width: 12),
              _buildColorSwatch('Tertiary', previewScheme.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeGrid(BuildContext context, FlexScheme currentScheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: AppTheme.availableSchemes.length,
      itemBuilder: (context, index) {
        final scheme = AppTheme.availableSchemes[index];
        final isSelected = scheme == currentScheme;

        return _buildSchemeCard(context, scheme, isSelected, isDark);
      },
    );
  }

  Widget _buildSchemeCard(
    BuildContext context,
    FlexScheme scheme,
    bool isSelected,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    // Get colors for this scheme
    final schemeColors = isDark
        ? FlexColorScheme.dark(scheme: scheme).toScheme
        : FlexColorScheme.light(scheme: scheme).toScheme;

    return InkWell(
      onTap: () {
        context.read<ThemeBloc>().add(
          ThemePaletteChanged(ThemePalette(scheme: scheme)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Color preview circles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniColorCircle(schemeColors.primary),
                const SizedBox(width: 4),
                _buildMiniColorCircle(schemeColors.secondary),
                const SizedBox(width: 4),
                _buildMiniColorCircle(schemeColors.tertiary),
              ],
            ),
            const SizedBox(height: 12),
            // Scheme name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                AppTheme.getSchemeName(scheme),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniColorCircle(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
