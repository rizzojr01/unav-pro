import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_sense/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smart_sense/features/auth/presentation/bloc/auth_event.dart';
import 'package:smart_sense/features/auth/presentation/bloc/auth_state.dart';

import '../../../../injection.dart';
import '../../../../shared/presentation/bloc/location_settings_bloc.dart';
import '../../../../shared/presentation/bloc/location_settings_event.dart';
import '../../../../shared/presentation/bloc/location_settings_state.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../theme/theme_bloc.dart';
import '../../../../theme/widgets/color_customizer.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is Authenticated ? state.user : null;
        return Container(
          color: theme.scaffoldBackgroundColor,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, state, user?.nickname ?? 'Guest'),
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
                          onTap: () => context.push('/localization-history'),
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
                          icon: Icons.location_on_outlined,
                          title: 'Location Settings',
                          subtitle: _getLocationSubtitle(),
                          onTap: () => _showLocationSettings(context),
                        ),
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
                          icon: Icons.palette_outlined,
                          title: 'Design & Colors',
                          subtitle: 'Personalize primary & background colors',
                          onTap: () => _showColorCustomizer(context),
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
                        _SettingsItem(
                          icon: Icons.compress_rounded,
                          title: 'Image Compression',
                          subtitle: 'Height, Width, Quality',
                          onTap: () => _showImageCompressionSettings(context),
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
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'DEVELOPER OPTIONS'),
                      const SizedBox(height: 12),
                      _buildDebugSection(context),
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
      },
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    AuthState state,
    String name,
  ) {
    final theme = Theme.of(context);

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
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),

            // Profile Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                _AvatarWidget(),
                const SizedBox(height: 16),
                Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state is Authenticated
                      ? state.user.email
                      : 'No email available',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.3 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _StatItem(label: 'TRIPS', value: '42'),
          _divider(context),
          const _StatItem(label: 'DISTANCE', value: '1.2 km'),
          _divider(context),
          const _StatItem(label: 'FLOORS', value: '18'),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 30,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
        letterSpacing: 3,
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: isDark ? 0.3 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.go('/login');
        }
      },
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Text(
            'LOGOUT',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
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

  String _getLocationSubtitle() {
    final locationConfig = getIt<LocationConfigService>();
    return '${locationConfig.building}, ${locationConfig.floor}';
  }

  Widget _buildDebugSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locationConfig = getIt<LocationConfigService>();

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(
                  alpha: isDark ? 0.3 : 0.03,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Use Sample Image Toggle
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bug_report_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Sample Image',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Skip camera, use test image for localization',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: locationConfig.useSampleImage,
                      onChanged: (value) async {
                        await locationConfig.setUseSampleImage(value);
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Sample image enabled - camera will be skipped'
                                    : 'Sample image disabled - camera will be used',
                              ),
                              backgroundColor: theme.colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      activeColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                indent: 68,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              // Floor Map Testing
              InkWell(
                onTap: () {
                  context.push('/floor-map');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.map_outlined,
                          color: theme.colorScheme.secondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Floor Map Testing',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Test interactive floor map with coordinate selection',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                indent: 68,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              // Info text
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'When enabled, the app will use a pre-configured sample image instead of capturing from camera.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BlocProvider(
        create: (context) =>
            getIt<LocationSettingsBloc>()
              ..add(const LoadLocationSettingsEvent()),
        child: const _LocationSettingsSheet(),
      ),
    );
  }

  void _showThemeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ThemeSelectionSheet(),
    );
  }

  void _showImageCompressionSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ImageCompressionSettingsSheet(),
    );
  }

  void _showColorCustomizer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'DESIGN & COLORS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const ColorCustomizer(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 22),
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.surface,
            child: Icon(
              Icons.person_rounded,
              size: 60,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
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

class _ImageCompressionSettingsSheet extends StatefulWidget {
  const _ImageCompressionSettingsSheet();

  @override
  State<_ImageCompressionSettingsSheet> createState() =>
      _ImageCompressionSettingsSheetState();
}

class _ImageCompressionSettingsSheetState
    extends State<_ImageCompressionSettingsSheet> {
  final _heightController = TextEditingController();
  final _widthController = TextEditingController();
  late bool _enabled;
  late double _quality;

  @override
  void initState() {
    super.initState();
    final config = getIt<LocationConfigService>();
    _enabled = config.enableCompression;
    _quality = config.imageQuality.toDouble();
    _heightController.text = config.maxHeight.toString();
    _widthController.text = config.maxWidth.toString();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = getIt<LocationConfigService>();
    final h = int.tryParse(_heightController.text) ?? 480;
    final w = int.tryParse(_widthController.text) ?? 640;

    await config.setEnableCompression(_enabled);
    await config.setMaxHeight(h);
    await config.setMaxWidth(w);
    await config.setImageQuality(_quality.round());

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'IMAGE COMPRESSION',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildToggle(theme),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    theme,
                    'Max Height',
                    _heightController,
                    Icons.height,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    theme,
                    'Max Width',
                    _widthController,
                    Icons.width_full,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildQualitySlider(theme),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.compress_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Enable Compression',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Switch.adaptive(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    ThemeData theme,
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'IMAGE QUALITY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${_quality.round()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: _quality,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => setState(() => _quality = v),
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

    return InkWell(
      onTap: () {
        context.read<ThemeBloc>().add(ThemeModeChanged(mode));
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationSettingsSheet extends StatelessWidget {
  const _LocationSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: BlocBuilder<LocationSettingsBloc, LocationSettingsState>(
          builder: (context, state) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'LOCATION SETTINGS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Select your current location',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (state is LocationSettingsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (state is LocationSettingsError)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load locations',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<LocationSettingsBloc>()
                              .add(const LoadLocationSettingsEvent()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (state is LocationSettingsLoaded)
                  _buildLocationForm(context, state)
                else
                  const SizedBox(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationForm(
    BuildContext context,
    LocationSettingsLoaded state,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Place Dropdown
        _buildDropdownSection(
          context: context,
          label: 'PLACE',
          value: state.selectedPlace,
          items: state.places.map((p) => p.name).toList(),
          onChanged: (value) {
            if (value != null) {
              context.read<LocationSettingsBloc>().add(SelectPlaceEvent(value));
            }
          },
        ),
        const SizedBox(height: 24),

        // Building Dropdown
        _buildDropdownSection(
          context: context,
          label: 'BUILDING',
          value: state.selectedBuilding,
          items:
              state.currentPlace?.buildings.map((b) => b.name).toList() ?? [],
          onChanged: (value) {
            if (value != null) {
              context.read<LocationSettingsBloc>().add(
                SelectBuildingEvent(value),
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // Floor Dropdown
        _buildDropdownSection(
          context: context,
          label: 'FLOOR',
          value: state.selectedFloor,
          items:
              state.currentBuilding?.floors.map((f) => f.name).toList() ?? [],
          onChanged: (value) {
            if (value != null) {
              context.read<LocationSettingsBloc>().add(SelectFloorEvent(value));
            }
          },
        ),
        const SizedBox(height: 40),

        // Save Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              context.read<LocationSettingsBloc>().add(
                const SaveLocationSettingsEvent(),
              );
              Navigator.pop(context);
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('Location settings saved'),
                  backgroundColor: theme.colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'SAVE SETTINGS',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSection({
    required BuildContext context,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value)
                  ? value
                  : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              dropdownColor: theme.colorScheme.surface,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item.replaceAll('_', ' '),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
