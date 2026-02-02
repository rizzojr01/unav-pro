import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/map_markers.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';

class MapViewWidget extends StatefulWidget {
  final LocationEntity currentLocation;
  final RouteEntity route;
  final String? floorPlanBase64;
  final VoidCallback? onRetry;
  final List<DestinationEntity> destinations;
  final Function(DestinationEntity)? onDestinationTap;

  const MapViewWidget({
    super.key,
    required this.currentLocation,
    required this.route,
    this.floorPlanBase64,
    this.onRetry,
    this.destinations = const [],
    this.onDestinationTap,
  });

  @override
  State<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends State<MapViewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final TransformationController _transformationController =
      TransformationController();
  Uint8List? _floorPlanBytes;
  bool _hasImageError = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _decodeFloorPlan();
  }

  void _decodeFloorPlan() {
    _hasImageError = false;
    _imageSize = null;
    if (widget.floorPlanBase64 != null && widget.floorPlanBase64!.isNotEmpty) {
      try {
        _floorPlanBytes = base64Decode(widget.floorPlanBase64!);
        _loadImageSize();
      } catch (e) {
        _floorPlanBytes = null;
        _hasImageError = true;
      }
    } else {
      _floorPlanBytes = null;
      _hasImageError = true;
    }
  }

  void _loadImageSize() {
    if (_floorPlanBytes == null) return;
    final image = MemoryImage(_floorPlanBytes!);
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
  void didUpdateWidget(covariant MapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floorPlanBase64 != widget.floorPlanBase64) {
      setState(() {
        _decodeFloorPlan();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show error state if floor plan is not available
    if (_hasImageError || _floorPlanBytes == null) {
      return _buildErrorView(theme);
    }

    // Wait for image size to be loaded
    if (_imageSize == null) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: Image.memory(_floorPlanBytes!, fit: BoxFit.contain),
        ),
      );
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Build a simple plotted route on top of the floor plan image.
          final route = widget.route;
          final steps = route.steps;

          // Collect coordinates in order
          final List<Offset> coords = [];
          for (final step in steps) {
            coords.add(Offset(step.from.x, step.from.y));
            coords.add(Offset(step.to.x, step.to.y));
          }

          // Use actual image dimensions for proper scaling
          final double floorPlanWidth = _imageSize!.width;
          final double floorPlanHeight = _imageSize!.height;

          return _buildInteractiveMap(
            theme,
            constraints,
            coords,
            floorPlanWidth,
            floorPlanHeight,
          );
        },
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.map_outlined,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Floor Plan Unavailable',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load the floor plan for this location. Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (widget.onRetry != null)
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Transform a point from API coordinates to screen coordinates
  Offset _transformPoint(
    double x,
    double y,
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
    double displayWidth,
    double displayHeight,
  ) {
    // Convert API coordinates to image-relative coordinates
    final imageX = x * scaleX;
    final imageY = y * scaleY;

    // Add the center offset (where image starts in the container)
    final baseX = imageX + centerOffsetX;
    final baseY = imageY + centerOffsetY;

    // Get the transformation matrix from InteractiveViewer
    final matrix = _transformationController.value;

    // Apply the full transformation
    final transformed = MatrixUtils.transformPoint(
      matrix,
      Offset(baseX, baseY),
    );

    return transformed;
  }

  Widget _buildInteractiveMap(
    ThemeData theme,
    BoxConstraints constraints,
    List<Offset> coords,
    double floorPlanWidth,
    double floorPlanHeight,
  ) {
    // Calculate the displayed image size maintaining aspect ratio
    final imageAspectRatio = floorPlanWidth / floorPlanHeight;
    final containerAspectRatio = constraints.maxWidth / constraints.maxHeight;

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
    final scaleX = displayWidth / floorPlanWidth;
    final scaleY = displayHeight / floorPlanHeight;

    // Center offset for the image within the container
    final centerOffsetX = (constraints.maxWidth - displayWidth) / 2;
    final centerOffsetY = (constraints.maxHeight - displayHeight) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Floor plan with InteractiveViewer
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(100),
          child: Center(
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // background map - use dynamic floor plan
                  Positioned.fill(
                    child: Image.memory(
                      _floorPlanBytes!,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) {
                        // Schedule error state update after build
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _hasImageError = true;
                            });
                          }
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ),

                  // overlay grid
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GridPainter(
                        theme.dividerColor.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                  // route paint layer with animation (path only, no markers)
                  if (coords.isNotEmpty)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(displayWidth, displayHeight),
                            painter: _RoutePainter(
                              coords: coords,
                              scaleX: scaleX,
                              scaleY: scaleY,
                              primaryColor: theme.colorScheme.primary,
                              animationValue: _controller.value,
                              drawMarkers: false,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Markers overlay - uses AnimatedBuilder to rebuild on transform changes
        if (coords.isNotEmpty)
          AnimatedBuilder(
            animation: _transformationController,
            builder: (context, child) {
              // Get current zoom scale from transformation matrix
              final matrix = _transformationController.value;
              final currentScale = matrix.getMaxScaleOnAxis();

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // POI markers (destination points of interest)
                  ...widget.destinations.map(
                    (destination) => _buildPOIMarker(
                      Offset(destination.x, destination.y),
                      destination.name,
                      scaleX,
                      scaleY,
                      centerOffsetX,
                      centerOffsetY,
                      displayWidth,
                      displayHeight,
                      theme,
                      currentScale,
                    ),
                  ),
                  // Destination flag marker
                  _buildDestinationMarker(
                    coords.last,
                    scaleX,
                    scaleY,
                    centerOffsetX,
                    centerOffsetY,
                    displayWidth,
                    displayHeight,
                    theme,
                    currentScale,
                  ),
                  // User position marker (on top)
                  _buildUserMarker(
                    coords.first,
                    scaleX,
                    scaleY,
                    centerOffsetX,
                    centerOffsetY,
                    displayWidth,
                    displayHeight,
                    theme,
                    currentScale,
                  ),
                ],
              );
            },
          ),

        // Map controls
        Positioned(
          right: 16,
          bottom: 16,
          child: _MapControlButton(
            icon: Icons.my_location,
            onPressed: _resetView,
            tooltip: 'Reset view',
          ),
        ),
      ],
    );
  }

  Widget _buildUserMarker(
    Offset coord,
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
    double displayWidth,
    double displayHeight,
    ThemeData theme,
    double zoomScale,
  ) {
    final pos = _transformPoint(
      coord.dx,
      coord.dy,
      scaleX,
      scaleY,
      centerOffsetX,
      centerOffsetY,
      displayWidth,
      displayHeight,
    );

    // Keep markers proportional to zoom level - wider range for better visibility
    // Markers grow when zooming in, shrink when zooming out
    const baseSize = 24.0;
    final markerSize = (baseSize * zoomScale).clamp(4.0, 72.0);

    // Get orientation from current location's 'ang' property if available,
    // otherwise fall back to first step's orientation
    double orientationDegrees = 0.0;
    if (widget.currentLocation.ang != null) {
      // Convert radians to degrees if ang is in radians
      // The ang value appears to be in radians based on the sample data (4.508...)
      orientationDegrees = widget.currentLocation.ang! * (180 / 3.14159265359);
    } else if (widget.route.steps.isNotEmpty) {
      orientationDegrees = widget.route.steps.first.orientationDegrees;
    }

    return Positioned(
      left: pos.dx - markerSize / 2,
      top: pos.dy - markerSize / 2,
      child: IgnorePointer(
        child: UserPositionMarker(
          size: markerSize,
          orientationDegrees: orientationDegrees,
          primaryColor: theme.colorScheme.primary,
          iconColor: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildDestinationMarker(
    Offset coord,
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
    double displayWidth,
    double displayHeight,
    ThemeData theme,
    double zoomScale,
  ) {
    final pos = _transformPoint(
      coord.dx,
      coord.dy,
      scaleX,
      scaleY,
      centerOffsetX,
      centerOffsetY,
      displayWidth,
      displayHeight,
    );

    // Keep markers proportional to zoom level - wider range for better visibility
    // Markers grow when zooming in, shrink when zooming out
    const baseSize = 24.0;
    final markerSize = (baseSize * zoomScale).clamp(4.0, 72.0);

    return Positioned(
      left: pos.dx - markerSize / 2,
      top: pos.dy - markerSize / 2,
      child: IgnorePointer(
        child: DestinationFlagMarker(
          size: markerSize,
          flagColor: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildPOIMarker(
    Offset coord,
    String name,
    double scaleX,
    double scaleY,
    double centerOffsetX,
    double centerOffsetY,
    double displayWidth,
    double displayHeight,
    ThemeData theme,
    double zoomScale,
  ) {
    final pos = _transformPoint(
      coord.dx,
      coord.dy,
      scaleX,
      scaleY,
      centerOffsetX,
      centerOffsetY,
      displayWidth,
      displayHeight,
    );

    // POI markers scale with zoom - wider range for better visibility
    const baseSize = 18.0;
    final markerSize = (baseSize * zoomScale).clamp(1.0, 60.0);

    return Positioned(
      left: pos.dx - markerSize / 2,
      top: pos.dy - markerSize / 2,
      child: DestinationMarker(
        size: markerSize,
        backgroundColor: theme.colorScheme.tertiary,
        iconColor: theme.colorScheme.onTertiary,
        icon: DestinationMarker.getIconForDestination(name),
        onTap: widget.onDestinationTap != null
            ? () {
                final results = widget.destinations.where(
                  (d) => d.name == name && d.x == coord.dx && d.y == coord.dy,
                );

                final destination = results.isNotEmpty
                    ? results.first
                    : DestinationEntity(
                        destinationId: 'poi_${name}_${coord.dx}_${coord.dy}',
                        name: name,
                        x: coord.dx,
                        y: coord.dy,
                      );
                widget.onDestinationTap!(destination);
              }
            : null,
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<Offset> coords;
  final double scaleX;
  final double scaleY;
  final Color primaryColor;
  final double animationValue;
  final bool drawMarkers;

  _RoutePainter({
    required this.coords,
    required this.scaleX,
    required this.scaleY,
    required this.primaryColor,
    required this.animationValue,
    this.drawMarkers = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coords.isEmpty) return;

    // Map floor plan coordinates to canvas coordinates using pre-calculated scale
    Offset mapPoint(Offset p) {
      return Offset(p.dx * scaleX, p.dy * scaleY);
    }

    // Build unique ordered points
    final List<Offset> points = [];
    for (final p in coords) {
      final mapped = mapPoint(p);
      if (points.isEmpty || (points.last - mapped).distance > 0.5) {
        points.add(mapped);
      }
    }

    if (points.isEmpty) return;

    final origin = points.first;
    final dest = points.last;

    // Create path
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    // === DRAW ROUTE PATH ===

    // 1. Outer glow/shadow for depth
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = primaryColor.withOpacity(0.15)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    // 2. White border for contrast
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, borderPaint);

    // 3. Main gradient path
    final pathMetrics = path.computeMetrics().first;
    final pathLength = pathMetrics.length;

    // Draw gradient segments along the path
    const segmentCount = 50;
    for (int i = 0; i < segmentCount; i++) {
      final start = i / segmentCount;
      final end = (i + 1) / segmentCount;

      final segmentPath = pathMetrics.extractPath(
        start * pathLength,
        end * pathLength,
      );

      // Gradient from origin color to destination color
      final t = i / segmentCount;
      final segmentColor = Color.lerp(
        const Color(0xFF4FC3F7), // Light blue at start
        primaryColor, // Primary color at end
        t,
      )!;

      final segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = segmentColor
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(segmentPath, segmentPaint);
    }

    // 4. Animated dash overlay for movement effect
    final dashPhase = animationValue * 40;
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.6)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Draw animated dashes
    const dashLength = 12.0;
    const gapLength = 20.0;
    double distance = dashPhase % (dashLength + gapLength);

    while (distance < pathLength) {
      final dashEnd = (distance + dashLength).clamp(0.0, pathLength);
      if (dashEnd > distance) {
        final dashPath = pathMetrics.extractPath(distance, dashEnd);
        canvas.drawPath(dashPath, dashPaint);
      }
      distance += dashLength + gapLength;
    }

    // === DRAW MARKERS (only if drawMarkers is true) ===
    if (drawMarkers) {
      _drawDestinationMarker(canvas, dest);
      _drawUserMarker(canvas, origin);
    }
  }

  void _drawDestinationMarker(Canvas canvas, Offset position) {
    // Subtle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(position + const Offset(0.5, 0.5), 5, shadowPaint);

    // Red fill with gradient
    final redGradient = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFEF5350), const Color(0xFFE53935)],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: position, radius: 7));
    canvas.drawCircle(position, 7, redGradient);

    // White inner dot
    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(position, 2.5, innerDot);
  }

  void _drawUserMarker(Canvas canvas, Offset position) {
    // Subtle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(position + const Offset(0.5, 0.5), 5, shadowPaint);

    // Blue/teal fill with gradient (like Google Maps style)
    final blueGradient = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: position, radius: 7));
    canvas.drawCircle(position, 7, blueGradient);

    // White inner dot
    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(position, 2.5, innerDot);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.coords != coords;
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
