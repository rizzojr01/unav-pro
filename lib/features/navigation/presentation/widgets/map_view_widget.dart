import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/map_markers.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';

class MapViewWidget extends StatefulWidget {
  final LocationEntity currentLocation;
  final RouteEntity route;
  final String? floorPlanBase64;
  final VoidCallback? onRetry;

  const MapViewWidget({
    super.key,
    required this.currentLocation,
    required this.route,
    this.floorPlanBase64,
    this.onRetry,
  });

  @override
  State<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends State<MapViewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final TransformationController _transformationController =
      TransformationController();
  double _rotation = 0.0;
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

  void _rotateMap(double delta) {
    setState(() {
      _rotation += delta;
    });
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _rotation = 0.0;
    });
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

    // Calculate user position for rotation origin
    Offset userPosition = Offset(displayWidth / 2, displayHeight / 2);
    if (widget.route.waypoints.isNotEmpty) {
      userPosition = Offset(
        widget.route.waypoints.first.x * scaleX,
        widget.route.waypoints.first.y * scaleY,
      );
    }

    // Apply rotation around user position
    final rotatedOffset = _rotatePoint(
      Offset(imageX, imageY),
      userPosition,
      _rotation,
    );

    // Add the center offset (where image starts in the container)
    final baseX = rotatedOffset.dx + centerOffsetX;
    final baseY = rotatedOffset.dy + centerOffsetY;

    // Get the transformation matrix from InteractiveViewer
    final matrix = _transformationController.value;

    // Apply the full transformation
    final transformed = MatrixUtils.transformPoint(
      matrix,
      Offset(baseX, baseY),
    );

    return transformed;
  }

  /// Rotate a point around an origin
  Offset _rotatePoint(Offset point, Offset origin, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final dx = point.dx - origin.dx;
    final dy = point.dy - origin.dy;
    return Offset(
      origin.dx + dx * cos - dy * sin,
      origin.dy + dx * sin + dy * cos,
    );
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

    // Calculate user position in widget coordinates for rotation origin
    Offset userPosition = Offset(displayWidth / 2, displayHeight / 2);
    if (coords.isNotEmpty) {
      userPosition = Offset(coords.first.dx * scaleX, coords.first.dy * scaleY);
    }

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
            child: Transform(
              alignment: FractionalOffset(
                userPosition.dx / displayWidth,
                userPosition.dy / displayHeight,
              ),
              transform: Matrix4.identity()..rotateZ(_rotation),
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

        // Rotation controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rotate left
              _MapControlButton(
                icon: Icons.rotate_left,
                onPressed: () => _rotateMap(-0.2),
                tooltip: 'Rotate left',
              ),
              const SizedBox(height: 8),
              // Rotate right
              _MapControlButton(
                icon: Icons.rotate_right,
                onPressed: () => _rotateMap(0.2),
                tooltip: 'Rotate right',
              ),
              const SizedBox(height: 8),
              // Reset view
              _MapControlButton(
                icon: Icons.my_location,
                onPressed: _resetView,
                tooltip: 'Reset view',
              ),
            ],
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

    // Keep markers proportional to zoom level
    // Markers grow when zooming in, shrink when zooming out
    const baseSize = 24.0;
    final markerSize = (baseSize * zoomScale).clamp(16.0, 48.0);

    // Get orientation from first step if available
    double orientationDegrees = 0.0;
    if (widget.route.steps.isNotEmpty) {
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

    // Keep markers proportional to zoom level
    // Markers grow when zooming in, shrink when zooming out
    const baseSize = 24.0;
    final markerSize = (baseSize * zoomScale).clamp(16.0, 48.0);

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
