import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/step_indicator.dart';
import '../../../../shared/widgets/custom_loading_view.dart';
import '../../../../shared/widgets/custom_error_view.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../bloc/navigation_bloc.dart';
import '../bloc/navigation_event.dart';
import '../bloc/navigation_state.dart';
import '../../domain/entities/route_entity.dart';
import '../../../../shared/widgets/map_view.dart';
import '../../../locate_me/presentation/widgets/destination_bottom_sheet.dart';

class NavigationPage extends StatefulWidget {
  final DestinationEntity destination;
  final String? imagePath;
  final Map<String, dynamic>? userPickedCoordinates;

  const NavigationPage({
    super.key,
    required this.destination,
    this.imagePath,
    this.userPickedCoordinates,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<NavigationBloc>();
    bloc.add(
      InitializeNavigationEvent(
        widget.destination,
        imagePath: widget.imagePath,
        userPickedCoordinates: widget.userPickedCoordinates,
      ),
    );
  }

  void _showDestinationBottomSheet(
    BuildContext context,
    DestinationEntity destination,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DestinationBottomSheet(
        destination: destination,
        onNavigate: () {
          if (modalContext.mounted) {
            Navigator.pop(modalContext);
          }
          if (mounted) {
            context.pushReplacement('/camera', extra: destination);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, state) {
          if (state is NavigationInitial || state is NavigationLoading) {
            return const CustomLoadingView(message: 'Initializing Map View...');
          } else if (state is NavigationReady) {
            return _NavigationMapView(
              destination: widget.destination,
              imagePath: widget.imagePath,
              currentLocation: state.currentLocation,
              route: state.route,
              floorPlanBase64: state.floorPlanBase64,
              destinations: state.destinations,
              onDestinationTap: (destination) =>
                  _showDestinationBottomSheet(this.context, destination),
              userPickedCoordinates: widget.userPickedCoordinates,
            );
          } else if (state is NavigationError) {
            return CustomErrorView(
              message: state.message,
              onRetry: () {
                context.read<NavigationBloc>().add(
                  InitializeNavigationEvent(
                    widget.destination,
                    imagePath: widget.imagePath,
                    userPickedCoordinates: widget.userPickedCoordinates,
                  ),
                );
              },
              onExit: () => context.pop(),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _NavigationMapView extends StatelessWidget {
  final DestinationEntity destination;
  final String? imagePath;
  final dynamic currentLocation;
  final RouteEntity route;
  final String? floorPlanBase64;
  final List<DestinationEntity> destinations;
  final Function(DestinationEntity)? onDestinationTap;
  final Map<String, dynamic>? userPickedCoordinates;

  const _NavigationMapView({
    required this.destination,
    this.imagePath,
    required this.currentLocation,
    required this.route,
    this.floorPlanBase64,
    this.destinations = const [],
    this.onDestinationTap,
    this.userPickedCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StepIndicator(
          currentStep: 3,
          title: 'Direct Guidance',
          onBack: () => context.pop(),
        ),
        Expanded(
          child: MapView(
            userLocation: currentLocation,
            route: route,
            floorPlanBase64: floorPlanBase64 ?? '',
            destinations: destinations,
            onDestinationTap: onDestinationTap,
            onRetry: () {
              context.read<NavigationBloc>().add(
                InitializeNavigationEvent(
                  destination,
                  imagePath: imagePath,
                  userPickedCoordinates: userPickedCoordinates,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
