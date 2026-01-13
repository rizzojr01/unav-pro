import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/step_indicator.dart';
import '../bloc/floor_map_bloc.dart';
import '../bloc/floor_map_event.dart';
import '../bloc/floor_map_state.dart';
import '../../domain/entities/destination_entity.dart';

class FloorMapPage extends StatefulWidget {
  const FloorMapPage({super.key});

  @override
  State<FloorMapPage> createState() => _FloorMapPageState();
}

class _FloorMapPageState extends State<FloorMapPage> {
  final TransformationController _transformationController = TransformationController();
  Offset? _markerPosition;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (context) => FloorMapBloc()..add(const FloorMapInitialized()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            StepIndicator(
              currentStep: 1,
              title: 'Point to your location on the map',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: BlocConsumer<FloorMapBloc, FloorMapState>(
                listener: (context, state) {
                  if (state is FloorMapMarkerPlaced) {
                    setState(() {
                      _markerPosition = state.markerPosition;
                    });
                  }
                },
                builder: (context, state) {
                  return Stack(
                    children: [
                      _buildFloorMap(context),
                      if (_markerPosition != null) _buildMarker(context),
                      if (_markerPosition != null) _buildConfirmButton(context),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorMap(BuildContext context) {
    final theme = Theme.of(context);
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: GestureDetector(
        onTapUp: (details) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            final mapSize = renderBox.size;
            context.read<FloorMapBloc>().add(
              FloorMapTapped(localPosition, mapSize),
            );
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: theme.colorScheme.surface,
          child: Center(
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Floor Plan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap anywhere to place your location',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: _markerPosition!.dx - 12,
      top: _markerPosition!.dy - 24,
      child: Icon(
        Icons.location_on_rounded,
        color: theme.colorScheme.primary,
        size: 24,
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      bottom: 32,
      left: 20,
      right: 20,
      child: ElevatedButton(
        onPressed: () {
          final state = context.read<FloorMapBloc>().state;
          if (state is FloorMapMarkerPlaced) {
            // Create a destination entity with the coordinates
            final destination = DestinationEntity(
              entityId: 'user_location_${DateTime.now().millisecondsSinceEpoch}',
              name: 'My Location',
              x: state.x,
              y: state.y,
              address: 'User selected location',
            );
            context.push('/camera', extra: destination);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirm Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}