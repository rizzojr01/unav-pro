import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../../shared/widgets/search_bar.dart';
import '../../../../shared/widgets/quick_action_card.dart';
import '../../../../shared/widgets/recent_place_tile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          onPressed: () {
            context.push('/destination');
          },
          backgroundColor: theme.primaryColor,
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
        color: isDark ? AppColors.secondary : theme.cardTheme.color,
        elevation: isDark ? 0 : 4,
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
              ? theme.primaryColor
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              child: Icon(Icons.person, color: theme.primaryColor),
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
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.meeting_room_rounded,
                title: 'Conference Room',
                color: AppColors.info,
                onTap: () => context.push('/destination'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.restaurant_rounded,
                title: 'Main Cafeteria',
                color: AppColors.warning,
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
                color: AppColors.error,
                onTap: () => context.push('/destination'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomQuickActionCard(
                icon: Icons.business_center_rounded,
                title: 'Lobby',
                color: AppColors.success,
                onTap: () => context.push('/destination'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentDestinationsList(BuildContext context) {
    return Column(
      children: [
        CustomRecentPlaceTile(
          name: 'Main Lobby',
          location: 'Ground Floor • Central',
          icon: Icons.meeting_room_outlined,
          onTap: () => context.push('/destination'),
        ),
        const SizedBox(height: 12),
        CustomRecentPlaceTile(
          name: 'Cafeteria',
          location: 'Second Floor • West Wing',
          icon: Icons.restaurant_menu,
          onTap: () => context.push('/destination'),
        ),
        const SizedBox(height: 12),
        CustomRecentPlaceTile(
          name: 'Meeting Room B',
          location: 'Third Floor • West Wing',
          icon: Icons.groups_outlined,
          onTap: () => context.push('/destination'),
        ),
      ],
    );
  }
}
