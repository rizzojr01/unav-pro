import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzy/fuzzy.dart';

import '../../features/ar_navigation/presentation/bloc/ar_navigation_bloc.dart';
import '../../features/ar_navigation/presentation/bloc/ar_navigation_state.dart';
import '../../features/destination/domain/entities/destination_entity.dart';
import '../../features/locate_me/domain/entities/user_position_entity.dart';
import '../../features/navigation/domain/entities/location_entity.dart';
import '../../features/navigation/domain/entities/route_entity.dart';
import '../../injection.dart';
import '../services/map_download_service.dart';
import 'map_controls_widget.dart';
import 'map_markers.dart';
import 'map_search_overlay.dart';

class MapView extends StatefulWidget {
  final dynamic userLocation;
  final RouteEntity? route;
  final String floorPlanBase64;
  final Function(DestinationEntity)? onDestinationTap;
  final List<DestinationEntity> destinations;
  final VoidCallback? onRetry;
  final VoidCallback? onRelocalize;
  final bool autoCenterOnUser;
  final String? currentFloor;
  final bool isCheckpoint;
  final double mapControlsRightOffset;

  final double? userHeading;
  final double? arRawHeading;
  final double? apiInitialHeading;

  const MapView({
    super.key,
    required this.userLocation,
    this.route,
    required this.floorPlanBase64,
    this.destinations = const [],
    this.onDestinationTap,
    this.currentFloor,
    this.isCheckpoint = false,
    this.mapControlsRightOffset = 0,
    this.autoCenterOnUser = true,
    this.onRetry,
    this.onRelocalize,
    this.userHeading,
    this.arRawHeading,
    this.apiInitialHeading,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  late AnimationController _routeAnimationController;
  final TransformationController _transformationController =
      TransformationController();

  Uint8List? _floorPlanBytes;
  Size? _imageSize;
  bool _hasImageError = false;
  bool _isSearching = false;
  bool _hasInitializedView = false;
  bool _isAutoCentered = true;

  final TextEditingController _searchController = TextEditingController();
  List<DestinationEntity> _filteredDestinations = [];

  @override
  void initState() {
    super.initState();
    _routeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _decodeFloorPlan();
    _filteredDestinations = widget.destinations;
    _searchController.addListener(_onSearchChanged);
  }

  void _decodeFloorPlan() {
    try {
      if (widget.floorPlanBase64.isNotEmpty) {
        _floorPlanBytes = base64Decode(widget.floorPlanBase64);
        _loadImageSize();
      } else {
        _hasImageError = true;
      }
    } catch (_) {
      _hasImageError = true;
    }
  }

  void _loadImageSize() {
    if (_floorPlanBytes == null) return;
    MemoryImage(_floorPlanBytes!)
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDestinations = widget.destinations;
      } else {
        final fuse = Fuzzy<DestinationEntity>(
          widget.destinations,
          options: FuzzyOptions(
            findAllMatches: true,
            tokenize: true,
            threshold: 0.4,
            keys: [
              WeightedKey(
                name: 'name',
                getter: (dest) => dest.name,
                weight: 0.6,
              ),
              WeightedKey(
                name: 'floor',
                getter: (dest) => dest.floor ?? '',
                weight: 0.4,
              ),
            ],
          ),
        );
        _filteredDestinations = fuse.search(query).map((r) => r.item).toList();
      }
    });
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floorPlanBase64 != widget.floorPlanBase64) {
      setState(() {
        _imageSize = null;
        _isAutoCentered = true;
        _hasInitializedView = false;
      });
      _decodeFloorPlan();
    }
    if (oldWidget.destinations != widget.destinations) {
      _filteredDestinations = widget.destinations;
    }

    if (oldWidget.userHeading != widget.userHeading &&
        widget.userHeading != null &&
        _imageSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;

        if (_isAutoCentered) {
          _recenterOnUser(
            box.size,
            _imageSize!,
            initialZoom: _transformationController.value.getMaxScaleOnAxis(),
            animate: true,
          );
        } else {
          _updateRotationOnly(box.size, _imageSize!);
        }
      });
    }

    final bool routeChanged =
        (oldWidget.route == null && widget.route != null) ||
        (oldWidget.route != null &&
            widget.route != null &&
            oldWidget.route!.entityId != widget.route!.entityId) ||
        (oldWidget.floorPlanBase64 != widget.floorPlanBase64);

    if (routeChanged && _imageSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        _recenterOnUser(box.size, _imageSize!, initialZoom: 3.5, animate: true);
      });
    }
  }

  @override
  void dispose() {
    _routeAnimationController.dispose();
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Offset _getUserCoords() {
    if (widget.isCheckpoint &&
        widget.route != null &&
        widget.route!.steps.isNotEmpty) {
      return Offset(
        widget.route!.steps.first.from.x,
        widget.route!.steps.first.from.y,
      );
    }
    if (widget.userLocation is LocationEntity) {
      return Offset(widget.userLocation.x, widget.userLocation.y);
    } else if (widget.userLocation is UserPositionEntity) {
      return Offset(widget.userLocation.x, widget.userLocation.y);
    }
    return Offset.zero;
  }

  void _initializeView(Size containerSize, Size imageSize) {
    if (_hasInitializedView || !widget.autoCenterOnUser) return;
    _hasInitializedView = true;
    _recenterOnUser(containerSize, imageSize, initialZoom: 3.5, animate: false);
  }

  void _recenterOnUser(
    Size containerSize,
    Size imageSize, {
    double initialZoom = 2.5,
    bool animate = false,
  }) {
    final userPos = _getUserCoords();
    final imageAR = imageSize.width / imageSize.height;
    final containerAR = containerSize.width / containerSize.height;

    double displayWidth, displayHeight;
    if (imageAR > containerAR) {
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAR;
    } else {
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAR;
    }

    final scaleX = displayWidth / imageSize.width;
    final scaleY = displayHeight / imageSize.height;
    final userDisplayX =
        userPos.dx * scaleX + (containerSize.width - displayWidth) / 2;
    final userDisplayY =
        userPos.dy * scaleY + (containerSize.height - displayHeight) / 2;

    // No automatic map rotation; keep North-up (0 deg)
    const rotation = 0.0;

    final targetMatrix = Matrix4.identity()
      ..translate(containerSize.width / 2, containerSize.height * 0.75)
      ..rotateZ(rotation)
      ..translate(-userDisplayX * initialZoom, -userDisplayY * initialZoom)
      ..scale(initialZoom);

    if (animate) {
      final animation =
          Matrix4Tween(
            begin: _transformationController.value,
            end: targetMatrix,
          ).animate(
            CurvedAnimation(
              parent: AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 300),
              )..forward(),
              curve: Curves.easeOutCubic,
            ),
          );
      animation.addListener(() {
        _transformationController.value = animation.value;
      });
    } else {
      _transformationController.value = targetMatrix;
    }
  }

  void _updateRotationOnly(Size containerSize, Size imageSize) {
    final userPos = _getUserCoords();
    final imageAR = imageSize.width / imageSize.height;
    final containerAR = containerSize.width / containerSize.height;

    double displayWidth, displayHeight;
    if (imageAR > containerAR) {
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAR;
    } else {
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAR;
    }

    final scaleX = displayWidth / imageSize.width;
    final scaleY = displayHeight / imageSize.height;
    final userDisplayX =
        userPos.dx * scaleX + (containerSize.width - displayWidth) / 2;
    final userDisplayY =
        userPos.dy * scaleY + (containerSize.height - displayHeight) / 2;

    final rotation = 0.0;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final userScreenPos = MatrixUtils.transformPoint(
      currentMatrix,
      Offset(userDisplayX, userDisplayY),
    );

    final targetMatrix = Matrix4.identity()
      ..translate(userScreenPos.dx, userScreenPos.dy)
      ..rotateZ(rotation)
      ..translate(-userDisplayX * currentScale, -userDisplayY * currentScale)
      ..scale(currentScale);

    _transformationController.value = targetMatrix;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hasImageError ||
        (_floorPlanBytes == null && widget.floorPlanBase64.isEmpty)) {
      return _buildErrorView(theme);
    }

    if (_imageSize == null) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        _initializeView(containerSize, _imageSize!);

        final imageAR = _imageSize!.width / _imageSize!.height;
        final containerAR = constraints.maxWidth / constraints.maxHeight;

        double displayWidth, displayHeight;
        if (imageAR > containerAR) {
          displayWidth = constraints.maxWidth;
          displayHeight = constraints.maxWidth / imageAR;
        } else {
          displayHeight = constraints.maxHeight;
          displayWidth = constraints.maxHeight * imageAR;
        }

        final scaleX = displayWidth / _imageSize!.width;
        final scaleY = displayHeight / _imageSize!.height;
        final centerOffsetX = (constraints.maxWidth - displayWidth) / 2;
        final centerOffsetY = (constraints.maxHeight - displayHeight) / 2;

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 8.0,
              boundaryMargin: const EdgeInsets.all(400),
              onInteractionStart: (details) {
                if (details.pointerCount > 0) {
                  setState(() => _isAutoCentered = false);
                }
              },
              child: Center(
                child: SizedBox(
                  width: displayWidth,
                  height: displayHeight,
                  child: Stack(
                    children: [
                      Image.memory(_floorPlanBytes!, fit: BoxFit.fill),
                      if (widget.route != null)
                        BlocBuilder<ArNavigationBloc, ArNavigationState>(
                          builder: (context, arState) {
                            List<Offset> pathCoords;
                            if (arState is ArNavigationTracking &&
                                arState.trackedPath.isNotEmpty) {
                              // If AR is tracking, use the dynamically updated path (includes user pos)
                              pathCoords = arState.trackedPath;
                            } else {
                              // Fallback to static route steps
                              pathCoords = widget.route!.steps
                                  .expand(
                                    (s) => [
                                      Offset(s.from.x, s.from.y),
                                      Offset(s.to.x, s.to.y),
                                    ],
                                  )
                                  .toList();
                            }

                            return AnimatedBuilder(
                              animation: _routeAnimationController,
                              builder: (context, _) => CustomPaint(
                                size: Size(displayWidth, displayHeight),
                                painter: RoutePainter(
                                  coords: pathCoords,
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  animationValue:
                                      _routeAnimationController.value,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Debug Info Panel
            Positioned(
              left: 16,
              top: 100,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'DEBUG INFO',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'API Ang: ${widget.apiInitialHeading?.toStringAsFixed(1) ?? "N/A"}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Pose Ang: ${widget.userHeading?.toStringAsFixed(1) ?? "N/A"}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'AR Raw: ${widget.arRawHeading?.toStringAsFixed(1) ?? "N/A"}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Map Rotation: ${(_transformationController.value.storage[1] != 0 || _transformationController.value.storage[0] != 0) ? (math.atan2(_transformationController.value.storage[1], _transformationController.value.storage[0]) * (180.0 / math.pi)).toStringAsFixed(1) : "0.0"}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Map X: ${_getUserCoords().dx.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Map Y: ${_getUserCoords().dy.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Auto-Center: $_isAutoCentered',
                        style: TextStyle(
                          color: _isAutoCentered ? Colors.green : Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            AnimatedBuilder(
              animation: _transformationController,
              builder: (context, _) {
                final zoom = _transformationController.value
                    .getMaxScaleOnAxis();
                return Stack(
                  children: [
                    ...widget.destinations.map(
                      (d) => _buildMarker(
                        d.x,
                        d.y,
                        scaleX,
                        scaleY,
                        centerOffsetX,
                        centerOffsetY,
                        zoom,
                        isPOI: true,
                        name: d.name,
                        destination: d,
                      ),
                    ),
                    if (widget.route != null && widget.route!.steps.isNotEmpty)
                      _buildMarker(
                        widget.route!.steps.last.to.x,
                        widget.route!.steps.last.to.y,
                        scaleX,
                        scaleY,
                        centerOffsetX,
                        centerOffsetY,
                        zoom,
                        isTarget: true,
                      ),
                    _buildMarker(
                      _getUserCoords().dx,
                      _getUserCoords().dy,
                      scaleX,
                      scaleY,
                      centerOffsetX,
                      centerOffsetY,
                      zoom,
                      isUser: true,
                      isCheckpoint: widget.isCheckpoint,
                      heading: widget.userHeading,
                    ),
                  ],
                );
              },
            ),
            MapControls(
              right: 16 + widget.mapControlsRightOffset,
              onSearch: () => setState(() => _isSearching = true),
              onReset: () {
                setState(() => _isAutoCentered = true);
                _recenterOnUser(
                  containerSize,
                  _imageSize!,
                  initialZoom: 3.5,
                  animate: true,
                );
              },
              onRelocalize: widget.onRelocalize,
            ),
            if (_isSearching)
              MapSearchOverlay(
                controller: _searchController,
                filteredDestinations: _filteredDestinations,
                onClose: () => setState(() => _isSearching = false),
                onDestinationTap: (d) {
                  setState(() => _isSearching = false);
                  widget.onDestinationTap?.call(d);
                },
              ),
            ValueListenableBuilder<MapSyncStatus>(
              valueListenable: getIt<MapDownloadService>().syncStatus,
              builder: (context, status, _) {
                if (!status.isSyncing && status.errorMessage == null) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (status.errorMessage != null
                                    ? Colors.red
                                    : theme.colorScheme.primaryContainer)
                                .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status.isSyncing)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white70,
                                ),
                              ),
                            )
                          else
                            Icon(
                              status.errorMessage != null
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              size: 16,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            status.isSyncing
                                ? 'Updating maps...'
                                : (status.errorMessage != null
                                      ? 'Map sync failed'
                                      : 'Maps updated'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMarker(
    double x,
    double y,
    double sX,
    double sY,
    double offX,
    double offY,
    double zoom, {
    bool isUser = false,
    bool isPOI = false,
    bool isTarget = false,
    bool isCheckpoint = false,
    double? heading,
    String? name,
    DestinationEntity? destination,
  }) {
    final matrix = _transformationController.value;
    final pos = MatrixUtils.transformPoint(
      matrix,
      Offset(x * sX + offX, y * sY + offY),
    );
    if (pos.dx.isNaN || pos.dy.isNaN) return const SizedBox.shrink();

    if (isUser) {
      final size = ((isCheckpoint ? 12.0 : 16.0) * zoom).clamp(4.0, 48.0);

      // Get the rotation of the map from the InteractiveViewer matrix
      final mapRotationRadians = math.atan2(
        matrix.storage[1],
        matrix.storage[0],
      );
      final mapRotationDegrees = mapRotationRadians * (180.0 / math.pi);

      // Use the heading provided (from API ang)
      // The arrow marker's internal 0 deg points Right (East).
      // We add the map's current rotation so the arrow stays relative to the floorplan.
      final markerHeading = (heading ?? 0.0) + mapRotationDegrees;

      return Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        child: UserPositionMarker(
          size: size,
          isCheckpoint: isCheckpoint,
          heading: markerHeading,
          showPulse: !isCheckpoint,
        ),
      );
    }

    if (isTarget) {
      final size = (12.0 * zoom).clamp(4.0, 40.0);
      return Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        child: DestinationFlagMarker(size: size),
      );
    }
    final size = (8.0 * zoom).clamp(1.5, 32.0);
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: DestinationMarker(
        size: size,
        icon: DestinationMarker.getIconForDestination(name ?? ''),
        onTap: destination != null
            ? () => widget.onDestinationTap?.call(destination)
            : null,
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading floor plan'),
          if (widget.onRetry != null)
            TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class RoutePainter extends CustomPainter {
  final List<Offset> coords;
  final double scaleX, scaleY;
  final double animationValue;

  RoutePainter({
    required this.coords,
    required this.scaleX,
    required this.scaleY,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coords.isEmpty) return;
    final valid = coords.where((c) => !c.dx.isNaN && !c.dy.isNaN).toList();
    if (valid.isEmpty) return;

    final path = Path()
      ..moveTo(valid.first.dx * scaleX, valid.first.dy * scaleY);
    Offset last = valid.first;
    for (var i = 1; i < valid.length; i++) {
      final c = valid[i];
      if ((c - last).distance > 2.0) {
        path.lineTo(c.dx * scaleX, c.dy * scaleY);
        last = c;
      }
    }

    final metrics = path.computeMetrics().isNotEmpty
        ? path.computeMetrics().first
        : null;
    if (metrics == null) return;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    const segCount = 40;
    final len = metrics.length;
    for (int i = 0; i < segCount; i++) {
      canvas.drawPath(
        metrics.extractPath(i / segCount * len, (i + 1) / segCount * len),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = Color.lerp(
            const Color(0xFF4FC3F7),
            const Color(0xFF2196F3),
            i / segCount,
          )!
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.6);
    const dashLen = 8.0, gapLen = 12.0;
    double dist = (animationValue * 30) % (dashLen + gapLen);
    while (dist < len) {
      canvas.drawPath(metrics.extractPath(dist, dist + dashLen), dashPaint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.animationValue != animationValue || old.coords != coords;
}
