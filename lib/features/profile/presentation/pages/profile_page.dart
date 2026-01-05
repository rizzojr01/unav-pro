import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/theme_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildUserStats(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'ACCOUNT'),
                  const SizedBox(height: 12),
                  _buildSettingsGroup(context, [
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      subtitle: 'Name, Email, Phone',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.history_rounded,
                      title: 'Navigation History',
                      subtitle: 'View your past trips',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Saved Places',
                      subtitle: 'Work, Home, Favorites',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'APP SETTINGS'),
                  const SizedBox(height: 12),
                  _buildSettingsGroup(context, [
                    _SettingsItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Alerts, Sounds, Vibration',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & Security',
                      subtitle: 'Permissions, Biometrics',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.dark_mode_outlined,
                      title: 'Appearance',
                      subtitle: _getThemeSubtitle(context),
                      onTap: () => _showThemeSelection(context),
                    ),
                    _SettingsItem(
                      icon: Icons.translate_rounded,
                      title: 'Language',
                      subtitle: 'English (US)',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'SUPPORT'),
                  const SizedBox(height: 12),
                  _buildSettingsGroup(context, [
                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help Center',
                      subtitle: 'FAQs, Contact Support',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About Smart Sense',
                      subtitle: 'Version 2.0.4',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 40),
                  _buildLogoutButton(context),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 280,
      backgroundColor: theme.scaffoldBackgroundColor,
      automaticallyImplyLeading: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Grid Background
            _GridBackground(
              color: theme.primaryColor.withValues(alpha: isDark ? 0.05 : 0.03),
            ),

            // Profile Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                _AvatarWidget(),
                const SizedBox(height: 16),
                Text(
                  'ALEX RIZZO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Senior UX Designer',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStats(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.05)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: 'TRIPS', value: '42'),
          _divider(context),
          _StatItem(label: 'DISTANCE', value: '1.2 km'),
          _divider(context),
          _StatItem(label: 'FLOORS', value: '18'),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 30,
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.05)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          ),
        ),
        child: const Text(
          'LOGOUT',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  String _getThemeSubtitle(BuildContext context) {
    final mode = context.watch<ThemeBloc>().state.themeMode;
    switch (mode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showThemeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ThemeSelectionSheet(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.secondaryDark.withValues(alpha: 0.5)
                    : theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.primaryColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.primaryColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: isDark
                ? AppColors.secondary
                : theme.cardTheme.color,
            child: Icon(
              Icons.person_rounded,
              size: 60,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.edit_rounded,
            size: 16,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _GridBackground extends StatelessWidget {
  final Color color;
  const _GridBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(color: color));
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 30.0;

    for (var i = 0.0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (var i = 0.0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThemeSelectionSheet extends StatelessWidget {
  const _ThemeSelectionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'APPEARANCE',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          _ThemeOption(
            title: 'Light Mode',
            icon: Icons.light_mode_rounded,
            mode: ThemeMode.light,
          ),
          const SizedBox(height: 12),
          _ThemeOption(
            title: 'Dark Mode',
            icon: Icons.dark_mode_rounded,
            mode: ThemeMode.dark,
          ),
          const SizedBox(height: 12),
          _ThemeOption(
            title: 'System Default',
            icon: Icons.settings_suggest_rounded,
            mode: ThemeMode.system,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final ThemeMode mode;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final currentMode = context.watch<ThemeBloc>().state.themeMode;
    final isSelected = currentMode == mode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        context.read<ThemeBloc>().add(ThemeChanged(mode));
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withValues(alpha: 0.1)
              : (isDark ? AppColors.secondary : theme.cardTheme.color),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor.withValues(alpha: 0.5)
                : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.primaryColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
