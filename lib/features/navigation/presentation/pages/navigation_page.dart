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
import '../widgets/map_view_widget.dart';

class NavigationPage extends StatefulWidget {
  final DestinationEntity destination;
  final String? imagePath;

  const NavigationPage({super.key, required this.destination, this.imagePath});

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
            );
          } else if (state is NavigationError) {
            return CustomErrorView(
              message: state.message,
              onRetry: () {
                context.read<NavigationBloc>().add(
                  InitializeNavigationEvent(
                    widget.destination,
                    imagePath: widget.imagePath,
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
  final dynamic route;
  final String? floorPlanBase64;
  final List<DestinationEntity> destinations;

  const _NavigationMapView({
    required this.destination,
    this.imagePath,
    required this.currentLocation,
    required this.route,
    this.floorPlanBase64,
    this.destinations = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StepIndicator(
          currentStep: 3,
          title: 'Route Preview',
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ClipRect(
            child: MapViewWidget(
              currentLocation: currentLocation,
              route: route,
              floorPlanBase64: floorPlanBase64,
              destinations: destinations,
              onRetry: () {
                context.read<NavigationBloc>().add(
                  InitializeNavigationEvent(destination, imagePath: imagePath),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
