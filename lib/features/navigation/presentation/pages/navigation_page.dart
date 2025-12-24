import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../bloc/navigation_bloc.dart';
import '../bloc/navigation_event.dart';
import '../bloc/navigation_state.dart';
import '../widgets/map_view_widget.dart';

class NavigationPage extends StatefulWidget {
  final DestinationEntity destination;

  const NavigationPage({super.key, required this.destination});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  @override
  void initState() {
    super.initState();
    context.read<NavigationBloc>().add(
      InitializeNavigationEvent(widget.destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              context.read<NavigationBloc>().add(const StopNavigationEvent());
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: BlocConsumer<NavigationBloc, NavigationState>(
        listener: (context, state) {
          if (state is NavigationCompleted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('You have arrived!')));
          } else if (state is NavigationError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is NavigationInitial || state is NavigationLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is NavigationReady) {
            return Column(
              children: [
                Expanded(
                  child: MapViewWidget(
                    currentLocation: state.currentLocation,
                    route: state.route,
                  ),
                ),
                _buildNavigationInfo(context, state),
                _buildStartButton(context),
              ],
            );
          } else if (state is NavigationInProgress) {
            return Column(
              children: [
                Expanded(
                  child: MapViewWidget(
                    currentLocation: state.currentLocation,
                    route: state.route,
                    isNavigating: true,
                  ),
                ),
                _buildNavigationInfo(context, state),
                _buildStopButton(context),
              ],
            );
          } else if (state is NavigationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NavigationBloc>().add(
                        InitializeNavigationEvent(widget.destination),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNavigationInfo(BuildContext context, dynamic state) {
    final route = state is NavigationReady
        ? state.route
        : state is NavigationInProgress
        ? state.route
        : null;

    if (route == null) return const SizedBox.shrink();

    final distanceKm = (route.distanceInMeters / 1000).toStringAsFixed(2);
    final durationMin = (route.durationInSeconds / 60).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            icon: Icons.straighten,
            label: 'Distance',
            value: '$distanceKm km',
          ),
          _buildInfoItem(
            icon: Icons.access_time,
            label: 'Duration',
            value: '$durationMin min',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.read<NavigationBloc>().add(const StartNavigationEvent());
          },
          icon: const Icon(Icons.navigation),
          label: const Text('Start Navigation'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.read<NavigationBloc>().add(const StopNavigationEvent());
          },
          icon: const Icon(Icons.stop),
          label: const Text('Stop Navigation'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.red,
          ),
        ),
      ),
    );
  }
}
