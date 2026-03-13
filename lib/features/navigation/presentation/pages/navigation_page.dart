import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../../../shared/services/floor_plan_cache_service.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/widgets/step_indicator.dart';
import '../../../../shared/widgets/custom_loading_view.dart';
import '../../../../shared/widgets/custom_error_view.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/entities/multi_floor_navigation_step_entity.dart';
import '../../domain/entities/navigation_step_entity.dart';
import '../bloc/navigation_bloc.dart';
import '../bloc/navigation_event.dart';
import '../bloc/navigation_state.dart';
import '../../../../shared/widgets/map_view.dart';
import '../../../locate_me/presentation/widgets/destination_bottom_sheet.dart';
import '../../../locate_me/domain/entities/user_position_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Page
// ─────────────────────────────────────────────────────────────────────────────

class NavigationPage extends StatefulWidget {
  final DestinationEntity destination;
  final String? imagePath;
  final Map<String, dynamic>? userPickedCoordinates;
  final String? pickedFloor;
  final double? heading;

  const NavigationPage({
    super.key,
    required this.destination,
    this.imagePath,
    this.userPickedCoordinates,
    this.pickedFloor,
    this.heading,
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
        heading: widget.heading,
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

          // If we have a current location from the existing route session,
          // reuse those coordinates to recalculate a new route without
          // forcing the user to take another photo.
          if (currentLocation != null) {
            context.read<NavigationBloc>().add(
              InitializeNavigationEvent(
                destination,
                userPickedCoordinates: {
                  'x': currentLocation.x,
                  'y': currentLocation.y,
                  'ang': currentLocation.ang,
                  'floor': currentLocation.floor,
                },
                pickedFloor: currentLocation.floor,
                // Passing null for imagePath/heading as we use coordinates
              ),
            );
          } else {
            // Fallback to original behaviour if coordinates aren't available
            if (mounted) context.pushReplacement('/camera', extra: destination);
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
          }
          if (state is NavigationReady) {
            return _NavigationMapView(
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
              captureHeading: widget.heading,
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
                  heading: widget.heading,
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

  /// Compass heading (degrees, North-based) at the moment the photo was taken.
  /// Pre-seeds the compass baseline so rotation is correct even if the user
  /// moved their phone while the map was loading.
  final double? captureHeading;

  const _NavigationMapView({
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
    this.captureHeading,
  });

  @override
  State<_NavigationMapView> createState() => _NavigationMapViewState();
}

class _NavigationMapViewState extends State<_NavigationMapView>
    with SingleTickerProviderStateMixin {
  late String _selectedFloor;
  late AnimationController _floorAnimController;

  /// Debug offsets for coordinate adjustment
  double _debugOffsetX = 0;
  double _debugOffsetY = 0;

  /// Local copy of floor plans — sourced from bloc state (pre-downloaded)
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

  void _showDebugNudgeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DebugCoordinateNudgeSheet(
        initialX: _debugOffsetX,
        initialY: _debugOffsetY,
        onUpdate: (x, y) {
          setState(() {
            _debugOffsetX = x;
            _debugOffsetY = y;
          });
        },
      ),
    );
  }

  /// Returns the user location with debug offsets applied
  dynamic get _nudgedLocation {
    final original = widget.currentLocation;
    if (original is LocationEntity) {
      return original.copyWith(
        x: original.x + _debugOffsetX,
        y: original.y + _debugOffsetY,
      );
    } else if (original is UserPositionEntity) {
      return original.copyWith(
        x: original.x + _debugOffsetX,
        y: original.y + _debugOffsetY,
      );
    }
    return original;
  }

  // "6_floor" → "6" · "B1_floor" → "B1" · "basement" → "B"
  String _floorLabel(String floor) {
    final cleaned = floor.replaceAll('_floor', '').replaceAll('_', ' ').trim();
    return cleaned.isEmpty ? floor : cleaned;
  }

  /// Ordered list of floors from the route (top → bottom = highest → lowest)
  List<MultiFloorNavigationStepEntity> get _orderedFloors {
    final floors = List<MultiFloorNavigationStepEntity>.from(
      widget.route.multiFloorSteps,
    );
    // Sort descending by numeric part if present
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

  /// Synthetic route showing only the selected floor's steps, with debug offsets applied
  RouteEntity get _routeForSelectedFloor {
    final floorSteps = widget.route.multiFloorSteps
        .where((f) => f.floor == _selectedFloor)
        .map((fStep) {
          // Apply debug offsets to every point in the route steps for this floor
          final nudgedSteps = fStep.steps.map((s) {
            return NavigationStepEntity(
              from: s.from.copyWith(
                x: s.from.x + _debugOffsetX,
                y: s.from.y + _debugOffsetY,
              ),
              to: s.to.copyWith(
                x: s.to.x + _debugOffsetX,
                y: s.to.y + _debugOffsetY,
              ),
              distanceMeters: s.distanceMeters,
              distanceFeet: s.distanceFeet,
              orientationDegrees: s.orientationDegrees,
              compassDirection: s.compassDirection,
            );
          }).toList();

          return MultiFloorNavigationStepEntity(
            floor: fStep.floor,
            steps: nudgedSteps,
          );
        })
        .toList();

    return RouteEntity(
      entityId: widget.route.entityId,
      multiFloorSteps: floorSteps,
    );
  }

  String get _floorPlanForSelected =>
      _floorPlansByFloor[_selectedFloor] ?? widget.floorPlanBase64 ?? '';

  /// Looks up the floor plan for [floorKey] from cache.
  /// All maps are pre-downloaded by MapDownloadService when the building
  /// is selected, so this is a synchronous cache hit in the normal case.
  void _ensureFloorPlanLoaded(String floorKey) {
    if (_floorPlansByFloor[floorKey]?.isNotEmpty == true) return;

    final config = getIt<LocationConfigService>();
    final cache = getIt<FloorPlanCacheService>();
    final cached = cache.getCachedFloorPlanBase64(
      place: config.place,
      building: config.building,
      floor: floorKey,
    );
    if (cached != null && cached.isNotEmpty) {
      setState(() => _floorPlansByFloor[floorKey] = cached);
    }
  }

  bool get _isMultiFloor => widget.route.multiFloorSteps.length > 1;

  /// Normalise floor key for comparison: "17_floor" → "17"
  String _normaliseFloor(String f) =>
      f.replaceAll('_floor', '').replaceAll('_', '').trim().toLowerCase();

  /// Returns destinations for the selected floor, filtered by the
  /// destination's own floor field as a safety net against cache contamination.
  List<DestinationEntity> get _destsForSelectedFloor {
    final normSelected = _normaliseFloor(_selectedFloor);

    // 1. Best case: the floor is indexed directly in destinationsByFloor.
    List<DestinationEntity>? raw = widget.destinationsByFloor[_selectedFloor];

    // 2. Fallback: scan ALL known per-floor slices + the base destinations list.
    //    This handles the case where a floor's data exists somewhere in the map
    //    but wasn't indexed under the exact _selectedFloor key (key format mismatch),
    //    and also covers non-starting floors that only returned data to the first
    //    floor's fetch (multifloor API returns all floors in one call).
    if (raw == null || raw.isEmpty) {
      final allKnown = [
        ...widget.destinationsByFloor.values.expand((list) => list),
        ...widget.destinations,
      ];
      raw = allKnown
          .where(
            (d) => d.floor != null && _normaliseFloor(d.floor!) == normSelected,
          )
          .toSet() // deduplicate in case the same destination appears in both sources
          .toList();
    }

    // 3. Final filter pass: strip any destinations whose floor field doesn't
    //    match the selected floor (prevents cross-floor POI bleed-through).
    return raw.where((d) {
      if (d.floor == null) return true; // no floor info → show on all floors
      return _normaliseFloor(d.floor!) == normSelected;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
              // ── Map ──────────────────────────────────────────────────────
              MapView(
                // No ValueKey here — preserves rotation when switching floors
                userLocation: _nudgedLocation,
                route: _routeForSelectedFloor,
                floorPlanBase64: _floorPlanForSelected,
                destinations: _destsForSelectedFloor,
                onDestinationTap: widget.onDestinationTap,
                currentFloor: widget.currentLocation.floor,
                isCheckpoint:
                    (_selectedFloor.replaceAll('_floor', '').trim() !=
                    widget.currentLocation.floor
                        ?.replaceAll('_floor', '')
                        .trim()),
                captureHeading: widget.captureHeading,
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
                onDebug: _showDebugNudgeSheet,
                mapControlsRightOffset: 0,
              ),

              // ── Floor Switcher Panel ──────────────────────────────────────
              if (_isMultiFloor)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 120, // Moved up to clear room for map controls
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
            ],
          ),
        ),
      ],
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
          // Header label
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

          // Floor buttons
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

class _DebugCoordinateNudgeSheet extends StatefulWidget {
  final double initialX;
  final double initialY;
  final Function(double x, double y) onUpdate;

  const _DebugCoordinateNudgeSheet({
    required this.initialX,
    required this.initialY,
    required this.onUpdate,
  });

  @override
  State<_DebugCoordinateNudgeSheet> createState() =>
      _DebugCoordinateNudgeSheetState();
}

class _DebugCoordinateNudgeSheetState
    extends State<_DebugCoordinateNudgeSheet> {
  late TextEditingController _xController;
  late TextEditingController _yController;

  @override
  void initState() {
    super.initState();
    _xController = TextEditingController(text: widget.initialX.toString());
    _yController = TextEditingController(text: widget.initialY.toString());
  }

  void _increment(bool isX, double delta) {
    if (isX) {
      final current = double.tryParse(_xController.text) ?? 0;
      final newVal = current + delta;
      _xController.text = newVal.toStringAsFixed(1);
      widget.onUpdate(newVal, double.tryParse(_yController.text) ?? 0);
    } else {
      final current = double.tryParse(_yController.text) ?? 0;
      final newVal = current + delta;
      _yController.text = newVal.toStringAsFixed(1);
      widget.onUpdate(double.tryParse(_xController.text) ?? 0, newVal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Coordinate Nudge',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _buildNudgeField('X Offset', _xController, true, theme),
          const SizedBox(height: 12),
          _buildNudgeField('Y Offset', _yController, false, theme),
        ],
      ),
    );
  }

  Widget _buildNudgeField(
    String label,
    TextEditingController controller,
    bool isX,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _CounterButton(
              icon: Icons.remove_rounded,
              onTap: () => _increment(isX, -5),
              isSecondary: true,
            ),
            const SizedBox(width: 8),
            _CounterButton(
              icon: Icons.remove_rounded,
              onTap: () => _increment(isX, -1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (s) {
                    final val = double.tryParse(s) ?? 0;
                    if (isX) {
                      widget.onUpdate(
                        val,
                        double.tryParse(_yController.text) ?? 0,
                      );
                    } else {
                      widget.onUpdate(
                        double.tryParse(_xController.text) ?? 0,
                        val,
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            _CounterButton(
              icon: Icons.add_rounded,
              onTap: () => _increment(isX, 1),
            ),
            const SizedBox(width: 8),
            _CounterButton(
              icon: Icons.add_rounded,
              onTap: () => _increment(isX, 5),
              isSecondary: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isSecondary;

  const _CounterButton({
    required this.icon,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSecondary
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: isSecondary ? 18 : 24,
            color: isSecondary
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
