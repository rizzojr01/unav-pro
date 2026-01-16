import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../../../shared/services/destinations_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/services/recent_destinations_service.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../../shared/widgets/search_bar.dart';
import '../../../../shared/widgets/quick_action_card.dart';
import '../../../../shared/widgets/recent_place_tile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<DestinationEntity> _recentDestinations = [];
  List<DestinationEntity> _popularPlaces = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _loadData() {
    // Load recent destinations
    final recentService = getIt<RecentDestinationsService>();
    _recentDestinations = recentService
        .getRecentDestinations()
        .take(3)
        .toList();

    // Load popular places from cached destinations
    final cacheService = getIt<DestinationsCacheService>();
    final locationService = getIt<LocationConfigService>();

    final cachedDestinations = cacheService.getCachedDestinations(
      place: locationService.place,
      building: locationService.building,
      floor: locationService.floor,
    );

    if (cachedDestinations != null && cachedDestinations.isNotEmpty) {
      // Get random destinations for popular places
      final shuffled = List<DestinationEntity>.from(cachedDestinations)
        ..shuffle(Random());
      _popularPlaces = shuffled.take(4).toList();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleLocateMe() {
    context.push('/locate-me').then((_) => _loadData());
  }

  void _handleNavigateMe() {
    context.push('/destination').then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SafeArea(child: _buildHomeContent(context)),
          const ProfilePage(),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 80,
        height: 80,
        child: FloatingActionButton(
          onPressed: _handleNavigateMe,
          backgroundColor: theme.colorScheme.primary,
          elevation: 4,
          shape: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.navigation_rounded,
                size: 32,
                color: theme.colorScheme.onPrimary,
              ),
              Text(
                'GO',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        color: theme.colorScheme.surface,
        elevation: theme.brightness == Brightness.dark ? 0 : 4,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(context, 0, Icons.home_filled, 'Home'),
              const SizedBox(width: 48), // Spacer for FAB
              _buildNavBarItem(context, 1, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final theme = Theme.of(context);
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header Section
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _buildHeader(context),
        ),

        // Top Tabs - Locate Me & Navigate Me
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: _buildTopTabs(context, theme),
        ),

        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(context),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Popular Places', () {}),
                const SizedBox(height: 16),
                _buildQuickActionsGrid(context),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Recent Destinations', () {
                  context.push('/destination');
                }),
                const SizedBox(height: 16),
                _buildRecentDestinationsList(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTabs(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              context,
              theme,
              icon: Icons.my_location_rounded,
              label: 'Locate Me',
              onTap: _handleLocateMe,
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabButton(
              context,
              theme,
              icon: Icons.navigation_rounded,
              label: 'Navigate Me',
              onTap: _handleNavigateMe,
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final color = isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hello!',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.person, color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Find your way',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return CustomSearchBar(
      hintText: 'Search destination...',
      onTap: () => context.push('/destination'),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    VoidCallback onAction,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (title == 'Recent Destinations')
          GestureDetector(
            onTap: onAction,
            child: Text(
              'See All',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final theme = Theme.of(context);

    // Use popular places from cache, or fallback to defaults
    if (_popularPlaces.isNotEmpty) {
      return _buildDynamicPopularPlaces(context, theme);
    }

    // Fallback static grid when no destinations cached
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.meeting_room_rounded,
                title: 'Conference Room',
                color: theme.colorScheme.primary,
                onTap: () => context.push('/destination'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.restaurant_rounded,
                title: 'Cafeteria',
                color: theme.colorScheme.secondary,
                onTap: () => context.push('/destination'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.wc_rounded,
                title: 'Restrooms',
                color: theme.colorScheme.tertiary,
                onTap: () => context.push('/destination'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.business_center_rounded,
                title: 'Lobby',
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.8,
                ),
                onTap: () => context.push('/destination'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDynamicPopularPlaces(BuildContext context, ThemeData theme) {
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.primaryContainer,
    ];

    final rows = <Widget>[];
    for (var i = 0; i < _popularPlaces.length; i += 2) {
      final first = _popularPlaces[i];
      final second = i + 1 < _popularPlaces.length
          ? _popularPlaces[i + 1]
          : null;

      rows.add(
        Row(
          children: [
            Expanded(
              child: CustomQuickActionCard(
                icon: _getIconForDestination(first.name),
                title: first.name,
                color: colors[i % colors.length],
                onTap: () => context.push('/camera', extra: first),
              ),
            ),
            const SizedBox(width: 16),
            if (second != null)
              Expanded(
                child: CustomQuickActionCard(
                  icon: _getIconForDestination(second.name),
                  title: second.name,
                  color: colors[(i + 1) % colors.length],
                  onTap: () => context.push('/camera', extra: second),
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < _popularPlaces.length) {
        rows.add(const SizedBox(height: 16));
      }
    }

    return Column(children: rows);
  }

  IconData _getIconForDestination(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('conference') || lowerName.contains('meeting')) {
      return Icons.meeting_room_rounded;
    } else if (lowerName.contains('cafeteria') ||
        lowerName.contains('restaurant') ||
        lowerName.contains('cafe')) {
      return Icons.restaurant_rounded;
    } else if (lowerName.contains('restroom') ||
        lowerName.contains('toilet') ||
        lowerName.contains('wc')) {
      return Icons.wc_rounded;
    } else if (lowerName.contains('lobby') || lowerName.contains('reception')) {
      return Icons.business_center_rounded;
    } else if (lowerName.contains('office')) {
      return Icons.work_outline_rounded;
    } else if (lowerName.contains('elevator') || lowerName.contains('lift')) {
      return Icons.elevator_rounded;
    } else if (lowerName.contains('stair')) {
      return Icons.stairs_rounded;
    } else if (lowerName.contains('exit')) {
      return Icons.exit_to_app_rounded;
    } else if (lowerName.contains('parking')) {
      return Icons.local_parking_rounded;
    }
    return Icons.place_rounded;
  }

  Widget _buildRecentDestinationsList(BuildContext context) {
    // Use actual recent destinations
    if (_recentDestinations.isNotEmpty) {
      return Column(
        children: _recentDestinations.asMap().entries.map((entry) {
          final index = entry.key;
          final destination = entry.value;
          return Column(
            children: [
              if (index > 0) const SizedBox(height: 12),
              CustomRecentPlaceTile(
                name: destination.name,
                location: destination.address ?? 'Location',
                icon: _getIconForDestination(destination.name),
                onTap: () => context.push('/camera', extra: destination),
              ),
            ],
          );
        }).toList(),
      );
    }

    // Fallback empty state
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No recent destinations',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start navigating to see your history',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
