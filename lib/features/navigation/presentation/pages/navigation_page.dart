import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../bloc/navigation_bloc.dart';
import '../bloc/navigation_event.dart';
import '../bloc/navigation_state.dart';
import 'package:smart_sense/shared/widgets/step_indicator.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
            return _NavigationInProgressView(
              state: state,
              destination: widget.destination,
            );
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

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Tech Grid Background
          CustomPaint(
            painter: _GridPainter(
              color: theme.primaryColor.withValues(alpha: isDark ? 0.05 : 0.03),
            ),
          ),

          // 2. Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow
                        Container(
                          width: 120 * _pulseAnimation.value,
                          height: 120 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        // Icon Container
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.secondary
                                : theme.primaryColor.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.explore_rounded,
                            size: 40,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'PREPARING NAV',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SYNCHRONIZING WITH SPATIAL DATA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.primaryColor.withValues(alpha: 0.7),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Progress
          Positioned(
            bottom: 80,
            left: 40,
            right: 40,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'CALCULATING OPTIMAL ROUTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

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

class _NavigationReadyView extends StatelessWidget {
  final DestinationEntity destination;
  final NavigationReady state;

  const _NavigationReadyView({required this.destination, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            StepIndicator(
              currentStep: 3,
              title: 'Final Destination',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: MapViewWidget(
                currentLocation: state.currentLocation,
                route: state.route,
              ),
            ),
            _buildRouteInfo(context, state),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ElevatedButton(
                onPressed: () {
                  context.read<NavigationBloc>().add(
                    const StartNavigationEvent(),
                  );
                },
                style: theme.elevatedButtonTheme.style?.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'START NAVIGATION',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.navigation_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(BuildContext context, NavigationReady state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final distanceM = state.route.distanceInMeters.round();
    final durationMin = (state.route.durationInSeconds / 60).round();

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoItem(
              icon: Icons.straighten_rounded,
              label: 'DISTANCE',
              value: '$distanceM m',
              iconColor: Colors.blue,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _InfoItem(
              icon: Icons.timer_rounded,
              label: 'EST. TIME',
              value: '$durationMin min',
              iconColor: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationInProgressView extends StatelessWidget {
  final DestinationEntity destination;
  final NavigationInProgress state;

  const _NavigationInProgressView({
    required this.destination,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            StepIndicator(
              currentStep: 3,
              title: destination.name,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: MapViewWidget(
                currentLocation: state.currentLocation,
                route: state.route,
                isNavigating: true,
              ),
            ),
            _buildActiveRouteInfo(context, state),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ElevatedButton(
                onPressed: () {
                  context.read<NavigationBloc>().add(
                    const StopNavigationEvent(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'END NAVIGATION',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.stop_circle_outlined),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRouteInfo(
    BuildContext context,
    NavigationInProgress state,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final distanceM = state.route.distanceInMeters.round();
    final durationMin = (state.route.durationInSeconds / 60).round();

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondary : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoItem(
              icon: Icons.straighten_rounded,
              label: 'REMAINING',
              value: '$distanceM m',
              iconColor: Colors.blue,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _InfoItem(
              icon: Icons.access_time_filled_rounded,
              label: 'ETA',
              value: '$durationMin min',
              iconColor: theme.primaryColor,
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
  final Color iconColor;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 48,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'SYSTEM ERROR',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<NavigationBloc>().add(
                            InitializeNavigationEvent(destination),
                          );
                        },
                        style: theme.elevatedButtonTheme.style,
                        child: const Text(
                          'RETRY CONNECTION',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
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
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
