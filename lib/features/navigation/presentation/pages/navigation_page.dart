import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/widgets/step_indicator.dart';
import '../../../../shared/widgets/custom_loading_view.dart';
import '../../../../shared/widgets/custom_error_view.dart';
import '../../../../shared/widgets/offset_settings_modal.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/multi_floor_navigation_step_entity.dart';
import '../../../ar_navigation/presentation/bloc/ar_navigation_bloc.dart';
import '../../../ar_navigation/presentation/bloc/ar_navigation_event.dart';
import '../../../ar_navigation/presentation/bloc/ar_navigation_state.dart';
import '../../../ar_navigation/presentation/widgets/ar_preview_floating_window.dart';
import '../../../ar_navigation/domain/entities/localized_pose.dart';
import '../bloc/navigation_bloc.dart';
import '../bloc/navigation_event.dart';
import '../bloc/navigation_state.dart';
import '../../../../shared/widgets/map_view.dart';
import '../../../locate_me/presentation/widgets/destination_bottom_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Page
// ─────────────────────────────────────────────────────────────────────────────

class NavigationPage extends StatefulWidget {
  final DestinationEntity destination;
  final String? imagePath;
  final Map<String, dynamic>? userPickedCoordinates;
  final String? pickedFloor;

  const NavigationPage({
    super.key,
    required this.destination,
    this.imagePath,
    this.userPickedCoordinates,
    this.pickedFloor,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  @override
  void initState() {
    super.initState();
    context.read<NavigationBloc>().add(
      InitializeNavigationEvent(
        widget.destination,
        imagePath: widget.imagePath,
        userPickedCoordinates: widget.userPickedCoordinates,
        pickedFloor: widget.pickedFloor,
      ),
    );
  }

  void _showDestinationBottomSheet(
    BuildContext context,
    DestinationEntity destination,
    LocationEntity? currentLocation,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DestinationBottomSheet(
        destination: destination,
        onNavigate: () {
          if (modalContext.mounted) Navigator.pop(modalContext);

          if (currentLocation != null) {
            context.read<NavigationBloc>().add(
              InitializeNavigationEvent(
                destination,
                userPickedCoordinates: {
                  'x': currentLocation.x,
                  'y': currentLocation.y,
                  'floor': currentLocation.floor,
                  'enabled': true,
                },
                pickedFloor: currentLocation.floor,
              ),
            );
          } else {
            if (mounted) context.pushReplacement('/camera', extra: destination);
          }
        },
      ),
    );
  }

  void _startArTracking(NavigationReady state) {
    if (context.read<ArNavigationBloc>().state is ArNavigationTracking) {
      return;
    }
    final floorScale = state.metersPerPixel ?? 1.0;

    // Check if the current location has an 'ang' (heading) from the backend
    final double initialHeading =
        state.currentLocation.ang ??
        widget.userPickedCoordinates?['heading']?.toDouble() ??
        0.0;

    context.read<ArNavigationBloc>().add(
      StartArNavigation(
        referencePose: LocalizedPose(
          floorKey: state.currentLocation.floor ?? 'unknown',
          x: state.currentLocation.x,
          y: state.currentLocation.y,
          z: 0,
          heading: initialHeading,
          confidence: 1.0,
          timestamp: DateTime.now(),
        ),
        metersPerPixel: floorScale,
        route: state.route,
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
          }
          if (state is NavigationReady) {
            _startArTracking(state);
            return _NavigationMapView(
              key: ValueKey(state.route.entityId),
              destination: widget.destination,
              imagePath: widget.imagePath,
              currentLocation: state.currentLocation,
              route: state.route,
              floorPlanBase64: state.floorPlanBase64,
              floorPlansByFloor: state.floorPlansByFloor,
              destinations: state.destinations,
              destinationsByFloor: state.destinationsByFloor,
              onDestinationTap: (d) => _showDestinationBottomSheet(
                this.context,
                d,
                state.currentLocation,
              ),
              userPickedCoordinates: widget.userPickedCoordinates,
              headingAtStart: state.headingAtStart,
              capturedReferenceHeading: state.capturedReferenceHeading,
            );
          }
          if (state is NavigationError) {
            return CustomErrorView(
              message: state.message,
              onRetry: () => context.read<NavigationBloc>().add(
                InitializeNavigationEvent(
                  widget.destination,
                  imagePath: widget.imagePath,
                  userPickedCoordinates: widget.userPickedCoordinates,
                  pickedFloor: widget.pickedFloor,
                ),
              ),
              onExit: () => context.pop(),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-floor map view (stateful to track selected floor)
// ─────────────────────────────────────────────────────────────────────────────

class _NavigationMapView extends StatefulWidget {
  final DestinationEntity destination;
  final String? imagePath;
  final dynamic currentLocation;
  final RouteEntity route;
  final String? floorPlanBase64;
  final Map<String, String> floorPlansByFloor;
  final List<DestinationEntity> destinations;
  final Map<String, List<DestinationEntity>> destinationsByFloor;
  final Function(DestinationEntity)? onDestinationTap;
  final Map<String, dynamic>? userPickedCoordinates;
  final double? headingAtStart;
  final double? capturedReferenceHeading;

  const _NavigationMapView({
    super.key,
    required this.destination,
    this.imagePath,
    required this.currentLocation,
    required this.route,
    this.floorPlanBase64,
    this.floorPlansByFloor = const {},
    this.destinations = const [],
    this.destinationsByFloor = const {},
    this.onDestinationTap,
    this.userPickedCoordinates,
    this.headingAtStart,
    this.capturedReferenceHeading,
  });

  @override
  State<_NavigationMapView> createState() => _NavigationMapViewState();
}

class _NavigationMapViewState extends State<_NavigationMapView>
    with SingleTickerProviderStateMixin {
  late String _selectedFloor;
  late AnimationController _floorAnimController;
  late Map<String, String> _floorPlansByFloor;


  @override
  void initState() {
    super.initState();
    _selectedFloor = widget.route.multiFloorSteps.isNotEmpty
        ? widget.route.multiFloorSteps.first.floor
        : 'unknown';

    _floorPlansByFloor = Map<String, String>.from(widget.floorPlansByFloor);

    _floorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _floorAnimController.forward();

  }

  @override
  void didUpdateWidget(_NavigationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floorPlansByFloor != widget.floorPlansByFloor) {
      _floorPlansByFloor = {..._floorPlansByFloor, ...widget.floorPlansByFloor};
    }
  }

  @override
  void dispose() {
    _floorAnimController.dispose();
    super.dispose();
  }

  String _floorLabel(String floor) {
    final cleaned = floor.replaceAll('_floor', '').replaceAll('_', ' ').trim();
    return cleaned.isEmpty ? floor : cleaned;
  }

  List<MultiFloorNavigationStepEntity> get _orderedFloors {
    final floors = List<MultiFloorNavigationStepEntity>.from(
      widget.route.multiFloorSteps,
    );
    floors.sort((a, b) {
      final aNum = _extractFloorNumber(a.floor);
      final bNum = _extractFloorNumber(b.floor);
      if (aNum != null && bNum != null) return bNum.compareTo(aNum);
      return a.floor.compareTo(b.floor);
    });
    return floors;
  }

  int? _extractFloorNumber(String floor) {
    final match = RegExp(r'(\d+)').firstMatch(floor);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  RouteEntity get _routeForSelectedFloor {
    final floorSteps = widget.route.multiFloorSteps
        .where((f) => f.floor == _selectedFloor)
        .toList();

    return RouteEntity(
      entityId: widget.route.entityId,
      multiFloorSteps: floorSteps,
    );
  }

  String get _floorPlanForSelected =>
      _floorPlansByFloor[_selectedFloor] ?? widget.floorPlanBase64 ?? '';

  Future<void> _ensureFloorPlanLoaded(String floorKey) async {
    if (_floorPlansByFloor[floorKey]?.isNotEmpty == true) return;

    final config = getIt<LocationConfigService>();
    final cache = getIt<FloorPlanCacheService>();
    final cached = await cache.getCachedFloorPlanBase64(
      place: config.place,
      building: config.building,
      floor: floorKey,
    );
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() => _floorPlansByFloor[floorKey] = cached);
      }
    }
  }

  bool get _isMultiFloor => widget.route.multiFloorSteps.length > 1;

  String _normaliseFloor(String f) =>
      f.replaceAll('_floor', '').replaceAll('_', '').trim().toLowerCase();

  List<DestinationEntity> get _destsForSelectedFloor {
    final normSelected = _normaliseFloor(_selectedFloor);
    List<DestinationEntity>? raw = widget.destinationsByFloor[_selectedFloor];

    if (raw == null || raw.isEmpty) {
      final allKnown = [
        ...widget.destinationsByFloor.values.expand((list) => list),
        ...widget.destinations,
      ];
      raw = allKnown
          .where(
            (d) => d.floor != null && _normaliseFloor(d.floor!) == normSelected,
          )
          .toSet()
          .toList();
    }

    return raw.where((d) {
      if (d.floor == null) return true;
      return _normaliseFloor(d.floor!) == normSelected;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ArNavigationBloc, ArNavigationState>(
      builder: (context, arState) {
        dynamic displayLocation = widget.currentLocation;
        double? displayHeading;

        if (arState is ArNavigationTracking && arState.currentPose != null) {
          displayLocation = arState.currentPose!.toLocationEntity();
          displayHeading = arState.currentPose!.heading;
        }

        final arRawHeading = (arState is ArNavigationTracking)
            ? arState.currentPose?.heading
            : null;
        final apiInitialHeading =
            (widget.currentLocation as LocationEntity).ang ??
            widget.userPickedCoordinates?['heading']?.toDouble();

        return Column(
          children: [
            StepIndicator(
              currentStep: 3,
              title: 'Direct Guidance',
              onBack: () =>
                  context.pushReplacement('/camera', extra: widget.destination),
            ),
            Expanded(
              child: Stack(
                children: [
                  MapView(
                    userLocation: displayLocation,
                    userHeading: displayHeading,
                    arRawHeading: arRawHeading,
                    apiInitialHeading: apiInitialHeading,
                    capturedReferenceHeading: widget.capturedReferenceHeading ??
                        widget.userPickedCoordinates?['heading']?.toDouble(),
                    headingAtStart: widget.headingAtStart,
                    route: _routeForSelectedFloor,
                    floorPlanBase64: _floorPlanForSelected,
                    destinations: _destsForSelectedFloor,
                    onDestinationTap: widget.onDestinationTap,
                    currentFloor: displayLocation.floor,
                    isCheckpoint:
                        (_selectedFloor.replaceAll('_floor', '').trim() !=
                        displayLocation.floor?.replaceAll('_floor', '').trim()),
                    onRetry: () => context.read<NavigationBloc>().add(
                      InitializeNavigationEvent(
                        widget.destination,
                        imagePath: widget.imagePath,
                        userPickedCoordinates: widget.userPickedCoordinates,
                        pickedFloor: _selectedFloor,
                      ),
                    ),
                    onRelocalize: () => context.pushReplacement(
                      '/camera',
                      extra: widget.destination,
                    ),
                    mapControlsRightOffset: 0,
                  ),

                  if (_isMultiFloor)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 120,
                      child: Center(
                        child: _FloorSwitcherPanel(
                          floors: _orderedFloors,
                          selectedFloor: _selectedFloor,
                          floorLabel: _floorLabel,
                          onFloorSelected: (floor) {
                            if (floor == _selectedFloor) return;
                            _ensureFloorPlanLoaded(floor);
                            setState(() {
                              _selectedFloor = floor;
                              _floorAnimController.reset();
                              _floorAnimController.forward();
                            });
                          },
                        ),
                      ),
                    ),

                  Positioned(
                    left: 16,
                    bottom: 80,
                    child: FloatingActionButton.small(
                      onPressed: () => showOffsetSettingsModal(context),
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.primary,
                      heroTag: 'offset_settings_fab_navigation',
                      child: const Icon(Icons.height),
                    ),
                  ),

                  Positioned(
                    right: 16,
                    top: 10,
                    child: ArPreviewFloatingWindow(
                      onTap: () {
                        // Handle toggle or full screen
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floor Switcher Panel Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FloorSwitcherPanel extends StatelessWidget {
  final List<MultiFloorNavigationStepEntity> floors;
  final String selectedFloor;
  final String Function(String) floorLabel;
  final ValueChanged<String> onFloorSelected;

  const _FloorSwitcherPanel({
    required this.floors,
    required this.selectedFloor,
    required this.floorLabel,
    required this.onFloorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(-2, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Floor',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),

          ...floors.asMap().entries.map((entry) {
            final idx = entry.key;
            final floorEntity = entry.value;
            final isSelected = floorEntity.floor == selectedFloor;
            final label = floorLabel(floorEntity.floor);
            final isFirst = idx == 0;
            final isLast = idx == floors.length - 1;

            return _FloorButton(
              label: label,
              isSelected: isSelected,
              isFirst: isFirst,
              isLast: isLast,
              onTap: () => onFloorSelected(floorEntity.floor),
            );
          }),
        ],
      ),
    );
  }
}

class _FloorButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _FloorButton({
    required this.label,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_FloorButton> createState() => _FloorButtonState();
}

class _FloorButtonState extends State<_FloorButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: widget.isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: widget.isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
