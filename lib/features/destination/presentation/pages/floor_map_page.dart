import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../injection.dart';
import '../../../../shared/widgets/step_indicator.dart';
import '../bloc/floor_map_bloc.dart';
import '../bloc/floor_map_event.dart';
import '../bloc/floor_map_state.dart';
import '../../domain/entities/destination_entity.dart';
import '../../../../shared/services/location_config_service.dart';
import '../../../../shared/widgets/floor_plan_selector_widget.dart';
import '../../../../shared/widgets/custom_loading_view.dart';
import '../../../../shared/widgets/custom_error_view.dart';
import '../../../../shared/widgets/offset_settings_modal.dart';

import 'package:flutter/cupertino.dart';

class FloorMapPage extends StatefulWidget {
  const FloorMapPage({super.key});

  @override
  State<FloorMapPage> createState() => _FloorMapPageState();
}

class _FloorMapPageState extends State<FloorMapPage> {
  FixedExtentScrollController? _floorController;
  late FloorMapBloc _floorMapBloc;

  @override
  void initState() {
    super.initState();
    _floorMapBloc = FloorMapBloc()..add(const FloorMapInitialized());
  }

  @override
  void dispose() {
    _floorController?.dispose();
    _floorMapBloc.close();
    super.dispose();
  }

  void _syncController(List<String> floors, String selectedFloor) {
    if (floors.isEmpty) return;
    final index = floors.indexOf(selectedFloor);
    if (index >= 0) {
      if (_floorController == null) {
        _floorController = FixedExtentScrollController(initialItem: index);
      } else if (_floorController!.hasClients &&
          _floorController!.selectedItem != index) {
        _floorController!.jumpToItem(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationConfig = getIt<LocationConfigService>();

    return BlocProvider.value(
      value: _floorMapBloc,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: BlocListener<FloorMapBloc, FloorMapState>(
          listener: (context, state) {
            if (state is FloorMapReady) {
              _syncController(state.availableFloors, state.selectedFloor);
            }
          },
          child: Stack(
            children: [
              Column(
                children: [
                  StepIndicator(
                    currentStep: 1,
                    title: 'Point to your location on the map',
                    onBack: () => context.pop(),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        BlocBuilder<FloorMapBloc, FloorMapState>(
                          builder: (context, state) {
                            if (state is FloorMapLoading) {
                              return const CustomLoadingView(
                                message: 'Loading floor plan...',
                              );
                            } else if (state is FloorMapReady) {
                              return FloorPlanSelectorWidget(
                                base64FloorPlan: state.base64FloorPlan,
                                onLocationSelected: (x, y) {
                                  final destination = DestinationEntity(
                                    destinationId:
                                        'manual_${DateTime.now().millisecondsSinceEpoch}',
                                    name: 'Selected Point',
                                    x: x,
                                    y: y,
                                    floor: state.selectedFloor,
                                    address:
                                        'Manual selection on ${state.selectedFloor}',
                                  );
                                  context.push('/camera', extra: destination);
                                },
                                confirmButtonText: 'Set Destination',
                              );
                            } else if (state is FloorMapError) {
                              return CustomErrorView(
                                message: state.message,
                                onRetry: () => context.read<FloorMapBloc>().add(
                                  const FloorMapInitialized(),
                                ),
                              );
                            }
                            return const CustomLoadingView();
                          },
                        ),
                        // Offset Settings Button
                        Positioned(
                          left: 16,
                          bottom: 110, // Above the confirm button
                          child: FloatingActionButton.small(
                            onPressed: () => showOffsetSettingsModal(context),
                            backgroundColor: theme.colorScheme.surface,
                            foregroundColor: theme.colorScheme.primary,
                            heroTag: 'offset_settings_fab',
                            child: const Icon(Icons.settings_input_component),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (locationConfig.multiFloorNavigation)
                BlocBuilder<FloorMapBloc, FloorMapState>(
                  builder: (context, state) {
                    if (state is FloorMapReady &&
                        state.availableFloors.isNotEmpty) {
                      _syncController(
                        state.availableFloors,
                        state.selectedFloor,
                      );

                      return Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                width: 48,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withOpacity(
                                    0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Selected Item Indicator Bar
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    CupertinoPicker(
                                      scrollController: _floorController,
                                      itemExtent: 38,
                                      diameterRatio: 0.8,
                                      squeeze: 1.2,
                                      magnification: 1.1,
                                      useMagnifier: true,
                                      onSelectedItemChanged: (index) {
                                        HapticFeedback.selectionClick();
                                        final newFloor =
                                            state.availableFloors[index];
                                        if (newFloor != state.selectedFloor) {
                                          context.read<FloorMapBloc>().add(
                                            FloorMapFloorChanged(newFloor),
                                          );
                                        }
                                      },
                                      children: state.availableFloors
                                          .map(
                                            (f) => Center(
                                              child: Text(
                                                f.replaceAll(
                                                  RegExp(r'[^0-9]'),
                                                  '',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
