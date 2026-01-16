import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_sense/injection.dart';
import 'package:smart_sense/shared/services/location_config_service.dart';
import 'package:smart_sense/shared/widgets/step_indicator.dart';
import 'package:smart_sense/shared/widgets/search_bar.dart';
import 'package:smart_sense/shared/widgets/custom_loading_view.dart';
import 'package:smart_sense/shared/widgets/custom_error_view.dart';

import '../bloc/destination_bloc.dart';
import '../bloc/destination_event.dart';
import '../bloc/destination_state.dart';

class DestinationPage extends StatefulWidget {
  const DestinationPage({super.key});

  @override
  State<DestinationPage> createState() => _DestinationPageState();
}

class _DestinationPageState extends State<DestinationPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Meeting Rooms',
    'Offices',
    'Cafeteria',
    'Restrooms',
  ];

  @override
  void initState() {
    super.initState();
    // Restore destinations when page is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<DestinationBloc>();
      final state = bloc.state;

      // If current state doesn't have destinations list, restore/fetch them
      if (state is! DestinationSearchSuccess) {
        bloc.add(const RestoreDestinationsEvent());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    if (_searchController.text.isNotEmpty) {
      context.read<DestinationBloc>().add(
        SearchDestinationsEvent(_searchController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          StepIndicator(
            currentStep: 1,
            title: 'Where would you like to go?',
            onBack: () => context.pop(),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: CustomSearchBar(
              readOnly: false,
              hintText: 'Search destination...',
              onChanged: (value) {
                context.read<DestinationBloc>().add(
                  SearchDestinationsEvent(value),
                );
              },
            ),
          ),
          buildCategories(context),
          Expanded(
            child: BlocConsumer<DestinationBloc, DestinationState>(
              listenWhen: (previous, current) {
                // Only listen for DestinationSelected if previous wasn't already selected
                // This prevents re-triggering navigation when coming back
                return current is DestinationSelected &&
                    previous is! DestinationSelected;
              },
              listener: (context, state) {
                if (state is DestinationSelected) {
                  context.push('/camera', extra: state.destination).then((_) {
                    // When returning from camera, restore the destinations list
                    context.read<DestinationBloc>().add(
                      const RestoreDestinationsEvent(),
                    );
                  });
                }
              },
              builder: (context, state) {
                if (state is DestinationInitial) {
                  return const _EmptyStateView();
                } else if (state is DestinationSearching) {
                  return const CustomLoadingView();
                } else if (state is DestinationSearchSuccess) {
                  if (state.destinations.isEmpty) {
                    return const _NoResultsView();
                  }
                  return _DestinationListView(destinations: state.destinations);
                } else if (state is DestinationSelected) {
                  // Show destinations while navigating or when coming back
                  if (state.destinations != null &&
                      state.destinations!.isNotEmpty) {
                    return _DestinationListView(
                      destinations: state.destinations!,
                    );
                  }
                  return const CustomLoadingView();
                } else if (state is DestinationError) {
                  return CustomErrorView(
                    message: state.message,
                    onRetry: _handleSearch,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildLocateMeButton(context),
        ],
      ),
    );
  }

  Widget _buildLocateMeButton(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        onPressed: () {
          context.push('/floor-map');
        },
        icon: Icon(
          Icons.my_location_rounded,
          color: theme.colorScheme.onPrimary,
        ),
        label: const Text('Locate Me on Map'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget buildCategories(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                context.read<DestinationBloc>().add(
                  SearchDestinationsEvent(category == 'All' ? '' : category),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Find Your Destination',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a location to start navigating',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationListView extends StatelessWidget {
  final List destinations;

  const _DestinationListView({required this.destinations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationConfigService = getIt<LocationConfigService>();
    final building = locationConfigService.building;
    final floor = locationConfigService.floor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(
            'Recommended',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final destination = destinations[index];
              return _DestinationTile(
                destination: destination,
                building: building,
                floor: floor,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final dynamic destination;
  final String building;
  final String floor;

  const _DestinationTile({
    required this.destination,
    required this.building,
    required this.floor,
  });

  /// Format building name from snake_case or PascalCase to readable format
  String _formatBuildingName(String building) {
    return building
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
  }

  /// Format floor name from "6_floor" format to "Floor 6"
  String _formatFloorName(String floor) {
    final floorNumber = floor.replaceAll(RegExp(r'[^0-9]'), '');
    if (floorNumber.isNotEmpty) {
      return 'Floor $floorNumber';
    }
    return floor.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.read<DestinationBloc>().add(
            SelectDestinationEvent(destination.id),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.2),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            destination.address ??
                                '${_formatBuildingName(building)} • ${_formatFloorName(floor)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Action Arrow
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.colorScheme.primary,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
