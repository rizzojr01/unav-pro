import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
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
      body: BlocConsumer<NavigationBloc, NavigationState>(
        listener: (context, state) {
          if (state is NavigationCompleted) {
            CustomSnackBar.show(
              context,
              message: 'You have arrived at your destination!',
              type: SnackBarType.success,
            );
          } else if (state is NavigationError) {
            CustomSnackBar.show(
              context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (context, state) {
          if (state is NavigationInitial || state is NavigationLoading) {
            return const _LoadingView();
          } else if (state is NavigationReady) {
            return _NavigationReadyView(
              destination: widget.destination,
              state: state,
            );
          } else if (state is NavigationInProgress) {
            return _NavigationInProgressView(state: state);
          } else if (state is NavigationError) {
            return _ErrorView(
              message: state.message,
              destination: widget.destination,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.accentGradient,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.white),
            SizedBox(height: 24),
            Text(
              'Preparing navigation...',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationReadyView extends StatelessWidget {
  final DestinationEntity destination;
  final NavigationReady state;

  const _NavigationReadyView({required this.destination, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: MapViewWidget(
              currentLocation: state.currentLocation,
              route: state.route,
            ),
          ),
          _buildRouteInfo(state),
          Padding(
            padding: const EdgeInsets.all(20),
            child: CustomButton(
              text: 'Start Navigation',
              onPressed: () {
                context.read<NavigationBloc>().add(
                  const StartNavigationEvent(),
                );
              },
              width: double.infinity,
              icon: Icons.navigation_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.accentGradient),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () {
                context.read<NavigationBloc>().add(const StopNavigationEvent());
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigation',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.name,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.white),
              onPressed: () {
                context.read<NavigationBloc>().add(const StopNavigationEvent());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(NavigationReady state) {
    final distanceKm = (state.route.distanceInMeters / 1000).toStringAsFixed(2);
    final durationMin = (state.route.durationInSeconds / 60).round();

    return CustomCard(
      margin: const EdgeInsets.all(16),
      hasShadow: true,
      child: Row(
        children: [
          Expanded(
            child: _InfoItem(
              icon: Icons.straighten_rounded,
              label: 'Distance',
              value: '$distanceKm km',
              gradient: AppColors.primaryGradient,
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.greyLight),
          Expanded(
            child: _InfoItem(
              icon: Icons.access_time_rounded,
              label: 'Duration',
              value: '$durationMin min',
              gradient: AppColors.secondaryGradient,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationInProgressView extends StatelessWidget {
  final NavigationInProgress state;

  const _NavigationInProgressView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildActiveHeader(context),
          Expanded(
            child: MapViewWidget(
              currentLocation: state.currentLocation,
              route: state.route,
              isNavigating: true,
            ),
          ),
          _buildActiveRouteInfo(state),
          Padding(
            padding: const EdgeInsets.all(20),
            child: CustomButton(
              text: 'Stop Navigation',
              onPressed: () {
                context.read<NavigationBloc>().add(const StopNavigationEvent());
              },
              backgroundColor: AppColors.error,
              width: double.infinity,
              icon: Icons.stop_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.successGradient),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigation Active',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Following your route...',
                    style: TextStyle(color: AppColors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRouteInfo(NavigationInProgress state) {
    final distanceKm = (state.route.distanceInMeters / 1000).toStringAsFixed(2);
    final durationMin = (state.route.durationInSeconds / 60).round();

    return CustomCard(
      margin: const EdgeInsets.all(16),
      hasShadow: true,
      color: AppColors.success.withValues(alpha: 0.1),
      child: Row(
        children: [
          Expanded(
            child: _InfoItem(
              icon: Icons.straighten_rounded,
              label: 'Remaining',
              value: '$distanceKm km',
              gradient: AppColors.primaryGradient,
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.greyLight),
          Expanded(
            child: _InfoItem(
              icon: Icons.access_time_rounded,
              label: 'ETA',
              value: '$durationMin min',
              gradient: AppColors.secondaryGradient,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(icon, color: AppColors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final DestinationEntity destination;

  const _ErrorView({required this.message, required this.destination});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Navigation Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 60,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Navigation Failed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Try Again',
                    onPressed: () {
                      context.read<NavigationBloc>().add(
                        InitializeNavigationEvent(destination),
                      );
                    },
                    width: double.infinity,
                    icon: Icons.refresh,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
