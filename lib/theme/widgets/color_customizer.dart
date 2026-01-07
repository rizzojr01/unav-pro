import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme_bloc.dart';
import '../theme_palette.dart';

class ColorCustomizer extends StatelessWidget {
  const ColorCustomizer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ThemeBloc>().state;
    final palette = state.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'THEME COLORS'),
        const SizedBox(height: 16),
        _buildColorTile(
          context,
          'Primary Color',
          'Buttons, highlighting, and main accents',
          palette.primary,
          (color) => _updatePalette(context, palette.copyWith(primary: color)),
        ),
        _buildColorTile(
          context,
          'Secondary Color',
          'UI elements and backgrounds',
          palette.secondary,
          (color) =>
              _updatePalette(context, palette.copyWith(secondary: color)),
        ),
        _buildColorTile(
          context,
          'Background',
          'App-wide background color',
          palette.background,
          (color) =>
              _updatePalette(context, palette.copyWith(background: color)),
        ),
        _buildColorTile(
          context,
          'Surface',
          'Cards, sheets, and dialogs',
          palette.surface,
          (color) => _updatePalette(context, palette.copyWith(surface: color)),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'PRESETS'),
        const SizedBox(height: 12),
        _buildPresets(context),
      ],
    );
  }

  void _updatePalette(BuildContext context, ThemePalette palette) {
    context.read<ThemeBloc>().add(ThemePaletteChanged(palette));
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildColorTile(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
    Function(Color) onColorSelected,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showColorPicker(context, title, onColorSelected),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.colorize_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    String title,
    Function(Color) onColorSelected,
  ) {
    final theme = Theme.of(context);
    final colors = [
      // Vibrant
      const Color(0xFFB8E600), // Original Lime
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFFF4081), // Pink
      const Color(0xFF7C4DFF), // Purple
      const Color(0xFFFFAB40), // Orange
      const Color(0xFF00E676), // Green
      // Sophisticated
      const Color(0xFF2962FF), // Deep Blue
      const Color(0xFFC2185B), // Raspberry
      const Color(0xFF006064), // Teal
      const Color(0xFFE65100), // Vernt Orange
      // Dark / Tech
      const Color(0xFF1E1E1E), // Slate
      const Color(0xFF121212), // Pitch Black
      const Color(0xFF37474F), // Blue Grey
      const Color(0xFFFFFFFF), // White
      const Color(0xFFF8F9FA), // Off White
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SELECT ${title.toUpperCase()}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    onColorSelected(colors[index]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPresets(BuildContext context) {
    final presets = [
      _ThemePreset(
        name: 'Cyberpunk',
        primary: const Color(0xFFB8E600),
        secondary: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
      ),
      _ThemePreset(
        name: 'Oceanic',
        primary: const Color(0xFF00E5FF),
        secondary: const Color(0xFF002B36),
        background: const Color(0xFF001F25),
      ),
      _ThemePreset(
        name: 'Rose Gold',
        primary: const Color(0xFFFF8A80),
        secondary: const Color(0xFF3E2723),
        background: const Color(0xFFFFEBEE),
      ),
      _ThemePreset(
        name: 'Monochrome',
        primary: const Color(0xFFFFFFFF),
        secondary: const Color(0xFF121212),
        background: const Color(0xFF000000),
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        itemBuilder: (context, index) {
          final preset = presets[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _updatePalette(
                context,
                ThemePalette(
                  primary: preset.primary,
                  secondary: preset.secondary,
                  background: preset.background,
                  surface: preset.background.withValues(
                    alpha: 0.8,
                  ), // Derived surface
                  error: const Color(0xFFFF5252),
                ),
              ),
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: preset.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: preset.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preset.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThemePreset {
  final String name;
  final Color primary;
  final Color secondary;
  final Color background;

  _ThemePreset({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.background,
  });
}
