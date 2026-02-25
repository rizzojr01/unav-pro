import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../../../shared/services/destinations_cache_service.dart';
import '../../../../shared/services/device_id_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../localization_history/presentation/bloc/localization_history_bloc.dart';
import '../../../localization_history/presentation/bloc/localization_history_event.dart';
import '../../../localization_history/presentation/bloc/localization_history_state.dart';
import '../../../../shared/widgets/recent_place_tile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
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
    // Load popular places from cached destinations
    final cacheService = getIt<DestinationsCacheService>();
    final locationService = getIt<LocationConfigService>();

    final cachedDestinations = cacheService.getCachedDestinations(
      place: locationService.place,
      building: locationService.building,
      floor: locationService.floor,
      multiFloor: locationService.multiFloorNavigation,
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

  void _handleProfile() {
    context.push('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => getIt<LocalizationHistoryBloc>(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _buildHeader(context),
              ),

              // Non-scrollable Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Navigate Me CTA
                      _buildNavigateMeButton(context, theme),

                      const SizedBox(height: 20),
                      _buildSectionHeader(context, 'Popular Places', () {}),
                      const SizedBox(height: 12),
                      _buildQuickActionsGrid(context),
                      const SizedBox(height: 20),
                      _buildSectionHeader(context, 'Recent Destinations', () {
                        context.push('/destination');
                      }),
                      const SizedBox(height: 12),
                      Expanded(child: _buildRecentDestinationsList(context)),
                    ],
                  ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unav',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              'Indoor Navigation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Locate Me Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleLocateMe,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Locate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Profile Icon
            InkWell(
              onTap: _handleProfile,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                child: Icon(Icons.person, color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigateMeButton(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleNavigateMe,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.navigation_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navigate Me',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      Text(
                        'Find your destination',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
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
            fontSize: 17,
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
                fontSize: 13,
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

    // Use popular places from cache
    if (_popularPlaces.isNotEmpty) {
      return _buildDynamicPopularPlaces(context, theme);
    }

    // Empty state when no destinations cached yet
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.explore_rounded,
            size: 40,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover Popular Places',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Places will appear here as you use the app',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPopularPlaces(BuildContext context, ThemeData theme) {
    final locationService = getIt<LocationConfigService>();
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < _popularPlaces.length; i++) ...[
            _buildPopularPlaceTile(
              context,
              theme,
              _popularPlaces[i],
              colors[i % colors.length],
              locationService,
            ),
            if (i < _popularPlaces.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 0,
                endIndent: 0,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPopularPlaceTile(
    BuildContext context,
    ThemeData theme,
    DestinationEntity destination,
    Color color,
    LocationConfigService locationService,
  ) {
    final subtitle = [
      if (locationService.floor.isNotEmpty) locationService.floor,
      if (locationService.building.isNotEmpty) locationService.building,
      if (locationService.place.isNotEmpty) locationService.place,
    ].join(' • ');

    return InkWell(
      onTap: () => context.push('/camera', extra: destination),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForDestination(destination.name),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
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
    return BlocBuilder<LocalizationHistoryBloc, LocalizationHistoryState>(
      builder: (context, state) {
        // Fetch localization history on first build
        if (state is LocalizationHistoryInitial) {
          final authState = context.read<AuthBloc>().state;
          final deviceIdService = getIt<DeviceIdService>();

          String userIdentifier;
          String identifierType;

          if (authState is Authenticated) {
            userIdentifier = authState.user.email;
            identifierType = 'email';
          } else {
            userIdentifier = deviceIdService.getDeviceId();
            identifierType = 'device';
          }

          context.read<LocalizationHistoryBloc>().add(
            FetchLocalizationHistoryEvent(
              userIdentifier: userIdentifier,
              identifierType: identifierType,
              limit: 10,
            ),
          );

          return const SizedBox();
        }

        if (state is LocalizationHistoryLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        if (state is LocalizationHistoryError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 32,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load history',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is LocalizationHistorySuccess) {
          final history = state.history;

          if (history.isEmpty) {
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

          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: history.take(3).map((item) {
              // Try to resolve a human-friendly name from cached destinations
              final cache = getIt<DestinationsCacheService>();
              String resolvedName = item.destinationName ?? item.destinationId;
              final cached = cache.getCachedDestinations(
                place: item.place,
                building: item.building,
                floor: item.floor,
                multiFloor: getIt<LocationConfigService>().multiFloorNavigation,
              );
              if (cached != null && cached.isNotEmpty) {
                final matches = cached
                    .where((d) => d.destinationId == item.destinationId)
                    .toList();
                if (matches.isNotEmpty) {
                  resolvedName = matches.first.name;
                }
              }

              return Column(
                children: [
                  CustomRecentPlaceTile(
                    name: resolvedName,
                    location:
                        '${item.building} • ${item.floor} • ${item.place}',
                    icon: Icons.location_on_rounded,
                    onTap: () {
                      // Navigate to camera with destination context
                      final destination = DestinationEntity(
                        destinationId: item.destinationId,
                        name: resolvedName,
                        x: 0,
                        y: 0,
                        floor: item.floor,
                        address: '${item.building} • ${item.floor}',
                      );
                      context.push('/camera', extra: destination);
                    },
                  ),
                  const SizedBox(height: 6),
                ],
              );
            }).toList(),
          );
        }

        return const SizedBox();
      },
    );
  }
}
