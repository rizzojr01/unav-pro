import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/map_markers.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../bloc/locate_me_bloc.dart';
import '../bloc/locate_me_event.dart';
import '../bloc/locate_me_state.dart';
import '../widgets/destination_bottom_sheet.dart';

class LocateMeFloorPlanPage extends StatefulWidget {
  const LocateMeFloorPlanPage({super.key});

  @override
  State<LocateMeFloorPlanPage> createState() => _LocateMeFloorPlanPageState();
}

class _LocateMeFloorPlanPageState extends State<LocateMeFloorPlanPage> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  void _showDestinationBottomSheet(
    BuildContext context,
    DestinationEntity destination,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DestinationBottomSheet(
        destination: destination,
        onNavigate: () {
          Navigator.pop(context);
          context.push('/camera', extra: destination);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<LocateMeBloc, LocateMeState>(
      builder: (context, state) {
        if (state is! LocateMeReady) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context, theme),
              Expanded(child: _buildFloorPlanView(context, theme, state)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _resetView,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.center_focus_strong,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              context.read<LocateMeBloc>().add(const ResetLocateMeEvent());
              context.pop();
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Expanded(
            child: Text(
              'Your Location',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              context.read<LocateMeBloc>().add(const ResetLocateMeEvent());
            },
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorPlanView(
    BuildContext context,
    ThemeData theme,
    LocateMeReady state,
  ) {
    // Decode base64 image
    final imageBytes = base64Decode(state.floorPlan.base64Image);

    return _FloorPlanWithMarkers(
      imageBytes: imageBytes,
      userPosition: state.userPosition,
      destinations: state.destinations,
      theme: theme,
      transformationController: _transformationController,
      onDestinationTap: (destination) =>
          _showDestinationBottomSheet(context, destination),
    );
  }
}

/// Widget that renders floor plan with properly positioned markers
class _FloorPlanWithMarkers extends StatefulWidget {
  final Uint8List imageBytes;
  final dynamic userPosition;
  final List<DestinationEntity> destinations;
  final ThemeData theme;
  final TransformationController transformationController;
  final Function(DestinationEntity) onDestinationTap;

  const _FloorPlanWithMarkers({
    required this.imageBytes,
    required this.userPosition,
    required this.destinations,
    required this.theme,
    required this.transformationController,
    required this.onDestinationTap,
  });

  @override
  State<_FloorPlanWithMarkers> createState() => _FloorPlanWithMarkersState();
}

class _FloorPlanWithMarkersState extends State<_FloorPlanWithMarkers> {
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  void _loadImageSize() {
    final image = MemoryImage(widget.imageBytes);
    image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (mounted) {
              setState(() {
                _imageSize = Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                );
              });
            }
          }),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSize == null) {
      return Image.memory(widget.imageBytes, fit: BoxFit.contain);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the displayed image size maintaining aspect ratio
        final imageAspectRatio = _imageSize!.width / _imageSize!.height;
        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;

        double displayWidth;
        double displayHeight;

        if (imageAspectRatio > containerAspectRatio) {
          // Image is wider - constrain by width
          displayWidth = constraints.maxWidth;
          displayHeight = constraints.maxWidth / imageAspectRatio;
        } else {
          // Image is taller - constrain by height
          displayHeight = constraints.maxHeight;
          displayWidth = constraints.maxHeight * imageAspectRatio;
        }

        // Scale factors to convert API coordinates to display coordinates
        final scaleX = displayWidth / _imageSize!.width;
        final scaleY = displayHeight / _imageSize!.height;

        // Center offset for the image within the container
        final centerOffsetX = (constraints.maxWidth - displayWidth) / 2;
        final centerOffsetY = (constraints.maxHeight - displayHeight) / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Floor plan with InteractiveViewer
            InteractiveViewer(
              transformationController: widget.transformationController,
              minScale: 0.5,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: Center(
                child: SizedBox(
                  width: displayWidth,
                  height: displayHeight,
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: widget.theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 80,
                                color:
                                    widget.theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              const Text('Floor plan not available'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Markers overlay - uses AnimatedBuilder to rebuild on transform changes
            AnimatedBuilder(
              animation: widget.transformationController,
              builder: (context, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Destination markers
                    ...widget.destinations.map(
                      (destination) => _buildDestinationMarker(
                        destination,
                        scaleX,
                        scaleY,
                        centerOffsetX,
                        centerOffsetY,
                      ),
                    ),
                    // User position marker (on top)
                    _buildUserMarker(
                      scaleX,
                      scaleY,
                      centerOffsetX,
                      centerOffsetY,
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Offset _transformPoint(
    double x,
    double y,
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
  ) {
    // Convert API coordinates to image-relative coordinates
    final imageX = x * scaleX;
    final imageY = y * scaleY;

    // Add the center offset (where image starts in the container)
    final baseX = imageX + centerOffsetX;
    final baseY = imageY + centerOffsetY;

    // Get the transformation matrix from InteractiveViewer
    final matrix = widget.transformationController.value;

    // Apply the full transformation
    final transformed = MatrixUtils.transformPoint(
      matrix,
      Offset(baseX, baseY),
    );

    return transformed;
  }

  Widget _buildUserMarker(
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
  ) {
    final pos = _transformPoint(
      widget.userPosition.x,
      widget.userPosition.y,
      scaleX,
      scaleY,
      centerOffsetX,
      centerOffsetY,
    );
    const markerSize = 24.0;

    // Convert radians to degrees for the marker
    final orientationDegrees =
        widget.userPosition.angle * (180 / 3.14159265359);

    return Positioned(
      left: pos.dx - markerSize / 2,
      top: pos.dy - markerSize / 2,
      child: IgnorePointer(
        child: UserPositionMarker(
          size: markerSize,
          orientationDegrees: orientationDegrees,
          primaryColor: widget.theme.colorScheme.primary,
          iconColor: widget.theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildDestinationMarker(
    DestinationEntity destination,
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
  ) {
    final pos = _transformPoint(
      destination.x,
      destination.y,
      scaleX,
      scaleY,
      centerOffsetX,
      centerOffsetY,
    );
    const markerSize = 20.0;

    return Positioned(
      left: pos.dx - markerSize / 2,
      top: pos.dy - markerSize / 2,
      child: DestinationMarker(
        size: markerSize,
        backgroundColor: widget.theme.colorScheme.error,
        iconColor: widget.theme.colorScheme.onError,
        icon: DestinationMarker.getIconForDestination(destination.name),
        onTap: () => widget.onDestinationTap(destination),
      ),
    );
  }
}
