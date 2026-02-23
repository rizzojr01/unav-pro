import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../features/destination/domain/entities/destination_entity.dart';
import '../../features/locate_me/domain/entities/user_position_entity.dart';
import '../../features/navigation/domain/entities/location_entity.dart';
import '../../features/navigation/domain/entities/route_entity.dart';
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
  final bool autoCenterOnUser;

  const MapView({
    super.key,
    required this.userLocation,
    this.route,
    required this.floorPlanBase64,
    this.onDestinationTap,
    this.destinations = const [],
    this.onRetry,
    this.autoCenterOnUser = true,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  late AnimationController _routeAnimationController;
  final TransformationController _transformationController =
      TransformationController();

  late AnimationController _snapRotationController;
  Animation<double>? _snapRotationAnimation;
  double _manualRotation = 0.0; // radians, current map rotation
  double _initialRouteRotation = 0.0; // radians, set from first route segment
  Matrix4? _initialMatrix; // transformation at initial view
  // Two-pointer rotation tracking
  final Map<int, Offset> _activePointers = {};
  double _lastPointerAngle = 0.0;
  double _gestureStartAngle = 0.0; // angle when second finger touched down
  bool _isTrackingRotation = false;
  bool _rotationThresholdMet = false; // only rotate after intentional twist
  static const double _rotationThreshold = 0.12; // ~7 degrees dead zone
  bool _showLegend = true;
  Uint8List? _floorPlanBytes;
  Size? _imageSize;
  bool _hasImageError = false;
  bool _isSearching = false;
  bool _hasInitializedView = false;
  bool _hasRecenteredOnUser = false;
  bool _hasSetInitialRotation = false;

  // Compass tracking
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _initialCompassHeading; // heading (degrees) when tracking started
  bool _compassActive = false; // true once the 2.5 s delay fires
  Timer? _compassStartTimer;

  final TextEditingController _searchController = TextEditingController();
  List<DestinationEntity> _filteredDestinations = [];

  @override
  void initState() {
    super.initState();
    _routeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _snapRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _decodeFloorPlan();
    _filteredDestinations = widget.destinations;
    _searchController.addListener(_onSearchChanged);
  }

  // ── compass ────────────────────────────────────────────────────────────────

  /// Starts compass tracking after [delay].
  /// Saves the heading at the moment tracking begins as the baseline,
  /// then applies: mapRotation = initialRouteRotation − deltaHeading.
  void _startCompassTracking({
    Duration delay = const Duration(milliseconds: 2500),
  }) {
    _compassStartTimer?.cancel();
    _compassStartTimer = Timer(delay, () {
      if (!mounted) return;
      _compassSubscription?.cancel();
      _initialCompassHeading = null; // will be set on first event
      _compassSubscription = FlutterCompass.events?.listen((event) {
        final heading = event.heading;
        if (heading == null || !mounted) return;

        // Capture the baseline heading on the very first event
        _initialCompassHeading ??= heading;

        // Compute how many degrees the user has physically rotated since we
        // started tracking, using the shortest arc to avoid 0/360 wrap issues.
        final delta = _shortestArc(heading - _initialCompassHeading!);

        // Rotate the map OPPOSITE to the physical rotation so the arrow stays up.
        setState(() {
          _manualRotation = _initialRouteRotation - delta * math.pi / 180.0;
          _compassActive = true;
        });
      });
    });
  }

  /// Returns the shortest signed arc (−180..+180) between two headings.
  double _shortestArc(double delta) {
    delta = delta % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  void _stopCompassTracking() {
    _compassStartTimer?.cancel();
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _initialCompassHeading = null;
    if (mounted) setState(() => _compassActive = false);
  }

  void _decodeFloorPlan() {
    try {
      if (widget.floorPlanBase64.isNotEmpty) {
        _floorPlanBytes = base64Decode(widget.floorPlanBase64);
        _loadImageSize();
      } else {
        _hasImageError = true;
      }
    } catch (e) {
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
                _setInitialRouteRotation();
              });
            }
          }),
        );
  }

  /// Rotates the map so the user's current facing direction points upward on screen.
  void _setInitialRouteRotation() {
    if (_hasSetInitialRotation) return;
    final route = widget.route;
    if (route == null || route.steps.isEmpty) return;
    _hasSetInitialRotation = true;

    // The backend provides `ang` on step 0's `from` — the user's current orientation.
    // `ang` uses the same convention as atan2: 0° = pointing right (+X in image space).
    // To make the user's facing direction point UP on screen we apply the same
    // formula as the atan2 segment method: -(ang_rad + π/2).
    // The +π/2 shifts the reference from "0°=right" to "0°=up".
    final userAngleDeg = route.steps.first.from.ang ?? 0.0;
    _manualRotation = -(userAngleDeg * math.pi / 180.0 + math.pi / 2);
    _initialRouteRotation = _manualRotation;

    // Start compass tracking 2.5 s after the initial view settles.
    // The delay lets the map animation finish before we hand control to the sensor.
    if (widget.route != null) {
      _startCompassTracking();
    }
  }

  /// Smoothly animates rotation AND position back to the initial view.
  void _snapToInitialRotation() {
    _snapRotationController.stop();

    final fromRotation = _manualRotation;
    final toRotation = _initialRouteRotation;
    final fromMatrix = _transformationController.value.clone();
    final toMatrix = _initialMatrix ?? _transformationController.value.clone();

    _snapRotationAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _snapRotationController,
            curve: Curves.easeInOutCubic,
          ),
        )..addListener(() {
          final t = _snapRotationAnimation!.value;
          // Interpolate rotation
          final newRotation = fromRotation + (toRotation - fromRotation) * t;
          // Interpolate each matrix entry
          final fromStorage = fromMatrix.storage;
          final toStorage = toMatrix.storage;
          final interpolated = Matrix4.fromList(
            List.generate(
              16,
              (i) => fromStorage[i] + (toStorage[i] - fromStorage[i]) * t,
            ),
          );
          setState(() => _manualRotation = newRotation);
          _transformationController.value = interpolated;
        });
    _snapRotationController.forward(from: 0);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDestinations = widget.destinations;
      } else {
        _filteredDestinations = widget.destinations
            .where((d) => d.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floorPlanBase64 != widget.floorPlanBase64) {
      _decodeFloorPlan();
    }
    if (oldWidget.destinations != widget.destinations) {
      _filteredDestinations = widget.destinations;
    }
    // If route arrives after image is already loaded, set initial rotation now
    if (oldWidget.route != widget.route && _imageSize != null) {
      _setInitialRouteRotation();
      // Recenter after rotation is applied
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final containerSize = box.size;
        _recenterOnUser(containerSize, _imageSize!, initialZoom: 2.0);
      });
    }
  }

  @override
  void dispose() {
    _compassStartTimer?.cancel();
    _compassSubscription?.cancel();
    _routeAnimationController.dispose();
    _snapRotationController.dispose();
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Offset _getUserCoords() {
    if (widget.userLocation is LocationEntity) {
      return Offset(widget.userLocation.x, widget.userLocation.y);
    } else if (widget.userLocation is UserPositionEntity) {
      return Offset(widget.userLocation.x, widget.userLocation.y);
    }
    return Offset.zero;
  }

  double _getUserAngle() {
    if (widget.userLocation is LocationEntity) {
      return widget.userLocation.ang ?? 0.0;
    } else if (widget.userLocation is UserPositionEntity) {
      return widget.userLocation.angle;
    }
    return 0.0;
  }

  void _initializeView(Size containerSize, Size imageSize) {
    if (_hasInitializedView || !widget.autoCenterOnUser) return;
    _hasInitializedView = true;
    // Set route rotation first so _recenterOnUser can account for it
    _setInitialRouteRotation();
    _recenterOnUser(containerSize, imageSize, initialZoom: 2.0);
  }

  void _recenterOnUser(
    Size containerSize,
    Size imageSize, {
    double initialZoom = 2.5,
  }) {
    final userPos = _getUserCoords();

    // Scale display image
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    double displayWidth, displayHeight;
    if (imageAspectRatio > containerAspectRatio) {
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAspectRatio;
    } else {
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAspectRatio;
    }

    final scaleX = displayWidth / imageSize.width;
    final scaleY = displayHeight / imageSize.height;

    // User position in the unrotated display coordinate space
    // (relative to the InteractiveViewer content origin)
    final userDisplayX =
        userPos.dx * scaleX + (containerSize.width - displayWidth) / 2;
    final userDisplayY =
        userPos.dy * scaleY + (containerSize.height - displayHeight) / 2;

    // Transform.rotate rotates around the display center.
    // We must rotate the user point by _manualRotation around that center
    // to find where the user will actually appear on screen.
    final cx = containerSize.width / 2;
    final cy = containerSize.height / 2;
    final dx = userDisplayX - cx;
    final dy = userDisplayY - cy;
    final cosA = math.cos(_manualRotation);
    final sinA = math.sin(_manualRotation);
    final rotatedUserX = cx + dx * cosA - dy * sinA;
    final rotatedUserY = cy + dx * sinA + dy * cosA;

    // Target: horizontally centered, 75% down (Google Maps style)
    final targetX = containerSize.width / 2;
    final targetY = containerSize.height * 0.75;

    final translateX = targetX - rotatedUserX * initialZoom;
    final translateY = targetY - rotatedUserY * initialZoom;

    final newMatrix = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(initialZoom);

    _transformationController.value = newMatrix;
    // Save as the initial view to return to when snap button is pressed
    _initialMatrix ??= newMatrix.clone();
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

        // Auto-recenter zoom after localization (first time)
        if (!_hasRecenteredOnUser && widget.autoCenterOnUser) {
          final userPos = _getUserCoords();
          if (userPos != Offset.zero) {
            _hasRecenteredOnUser = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                _recenterOnUser(containerSize, _imageSize!, initialZoom: 3.5);
            });
          }
        }

        final imageAspectRatio = _imageSize!.width / _imageSize!.height;
        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;

        double displayWidth, displayHeight;
        if (imageAspectRatio > containerAspectRatio) {
          displayWidth = constraints.maxWidth;
          displayHeight = constraints.maxWidth / imageAspectRatio;
        } else {
          displayHeight = constraints.maxHeight;
          displayWidth = constraints.maxHeight * imageAspectRatio;
        }

        final scaleX = displayWidth / _imageSize!.width;
        final scaleY = displayHeight / _imageSize!.height;
        final centerOffsetX = (constraints.maxWidth - displayWidth) / 2;
        final centerOffsetY = (constraints.maxHeight - displayHeight) / 2;

        final userAngle = _getUserAngle();
        // Manual hand rotation only
        final rotationAngle = _manualRotation;

        return Stack(
          children: [
            // Two-finger rotation detector (sits on top, doesn't block IV)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _activePointers[e.pointer] = e.localPosition;
                if (_activePointers.length == 2) {
                  final pts = _activePointers.values.toList();
                  _lastPointerAngle = math.atan2(
                    pts[1].dy - pts[0].dy,
                    pts[1].dx - pts[0].dx,
                  );
                  _gestureStartAngle = _lastPointerAngle;
                  _isTrackingRotation = true;
                  _rotationThresholdMet = false;
                  // User is manually rotating — pause compass so it doesn't fight the gesture
                  _stopCompassTracking();
                }
              },
              onPointerMove: (e) {
                _activePointers[e.pointer] = e.localPosition;
                if (_activePointers.length == 2 && _isTrackingRotation) {
                  final pts = _activePointers.values.toList();
                  final newAngle = math.atan2(
                    pts[1].dy - pts[0].dy,
                    pts[1].dx - pts[0].dx,
                  );
                  final delta = newAngle - _lastPointerAngle;

                  // Skip wrap-around jumps
                  if (delta.abs() > 0.3) {
                    _lastPointerAngle = newAngle;
                    return;
                  }

                  // Check if cumulative twist exceeds dead zone threshold
                  if (!_rotationThresholdMet) {
                    final cumulative = (newAngle - _gestureStartAngle).abs();
                    if (cumulative < _rotationThreshold) {
                      _lastPointerAngle = newAngle;
                      return; // still in dead zone — ignore
                    }
                    _rotationThresholdMet = true;
                  }

                  // Apply rotation — filter out tiny noise
                  if (delta.abs() > 0.005) {
                    // Compute user's current screen position BEFORE rotation
                    final userPos = _getUserCoords();
                    final matrix = _transformationController.value;

                    // User position in content (unrotated) space
                    final baseX = userPos.dx * scaleX + centerOffsetX;
                    final baseY = userPos.dy * scaleY + centerOffsetY;

                    // Content center (what Transform.rotate pivots around)
                    final contentCx = constraints.maxWidth / 2;
                    final contentCy = constraints.maxHeight / 2;

                    // Rotate user point by current rotation to get its position
                    // in the InteractiveViewer's coordinate space
                    final cosOld = math.cos(_manualRotation);
                    final sinOld = math.sin(_manualRotation);
                    final dxOld = baseX - contentCx;
                    final dyOld = baseY - contentCy;
                    final userInViewOldX =
                        contentCx + dxOld * cosOld - dyOld * sinOld;
                    final userInViewOldY =
                        contentCy + dxOld * sinOld + dyOld * cosOld;

                    // Same point after new rotation
                    final newRotation = _manualRotation + delta;
                    final cosNew = math.cos(newRotation);
                    final sinNew = math.sin(newRotation);
                    final userInViewNewX =
                        contentCx + dxOld * cosNew - dyOld * sinNew;
                    final userInViewNewY =
                        contentCy + dxOld * sinNew + dyOld * cosNew;

                    // The shift in InteractiveViewer space caused by the rotation
                    final shiftX = userInViewOldX - userInViewNewX;
                    final shiftY = userInViewOldY - userInViewNewY;

                    // Apply rotation and compensate translation atomically
                    final zoom = matrix.getMaxScaleOnAxis();
                    final newMatrix = matrix.clone()
                      ..translate(shiftX / zoom, shiftY / zoom);

                    setState(() => _manualRotation = newRotation);
                    _transformationController.value = newMatrix;
                  }
                  _lastPointerAngle = newAngle;
                }
              },
              onPointerUp: (e) {
                _activePointers.remove(e.pointer);
                if (_activePointers.length < 2) {
                  _isTrackingRotation = false;
                  _rotationThresholdMet = false;
                }
              },
              onPointerCancel: (e) {
                _activePointers.remove(e.pointer);
                if (_activePointers.length < 2) {
                  _isTrackingRotation = false;
                  _rotationThresholdMet = false;
                }
              },
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.1,
                maxScale: 8.0,
                boundaryMargin: const EdgeInsets.all(400),
                child: Transform.rotate(
                  angle: rotationAngle,
                  child: Center(
                    child: SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: Stack(
                        children: [
                          Image.memory(_floorPlanBytes!, fit: BoxFit.fill),

                          // Route Layer
                          if (widget.route != null)
                            AnimatedBuilder(
                              animation: _routeAnimationController,
                              builder: (context, _) => CustomPaint(
                                size: Size(displayWidth, displayHeight),
                                painter: RoutePainter(
                                  coords: widget.route!.steps
                                      .expand(
                                        (s) => [
                                          Offset(s.from.x, s.from.y),
                                          Offset(s.to.x, s.to.y),
                                        ],
                                      )
                                      .toList(),
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                  animationValue:
                                      _routeAnimationController.value,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Markers Layer
            AnimatedBuilder(
              animation: _transformationController,
              builder: (context, _) {
                final matrix = _transformationController.value;
                final zoomScale = matrix.getMaxScaleOnAxis();

                return Stack(
                  children: [
                    // POIs
                    ...widget.destinations.map(
                      (d) => _buildMarker(
                        d.x,
                        d.y,
                        scaleX,
                        scaleY,
                        centerOffsetX,
                        centerOffsetY,
                        zoomScale,
                        rotationAngle,
                        displayWidth,
                        displayHeight,
                        isPOI: true,
                        name: d.name,
                        destination: d,
                      ),
                    ),

                    // Destination Flag
                    if (widget.route != null && widget.route!.steps.isNotEmpty)
                      _buildMarker(
                        widget.route!.steps.last.to.x,
                        widget.route!.steps.last.to.y,
                        scaleX,
                        scaleY,
                        centerOffsetX,
                        centerOffsetY,
                        zoomScale,
                        rotationAngle,
                        displayWidth,
                        displayHeight,
                        isTarget: true,
                      ),

                    // User
                    _buildMarker(
                      _getUserCoords().dx,
                      _getUserCoords().dy,
                      scaleX,
                      scaleY,
                      centerOffsetX,
                      centerOffsetY,
                      zoomScale,
                      rotationAngle,
                      displayWidth,
                      displayHeight,
                      isUser: true,
                      angle: userAngle,
                    ),
                  ],
                );
              },
            ),

            MapControls(
              onSearch: () => setState(() => _isSearching = true),
              onReset: () {
                _hasRecenteredOnUser = false;
                _recenterOnUser(containerSize, _imageSize!);
              },
              onSnapRotation: () {
                _snapToInitialRotation();
                // Re-enable compass after snapping back to the route orientation
                _startCompassTracking(delay: const Duration(milliseconds: 800));
              },
              isAtInitialRotation:
                  (_manualRotation - _initialRouteRotation).abs() < 0.01,
            ),

            // Compass active indicator — top right
            if (widget.route != null)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    if (_compassActive) {
                      _stopCompassTracking();
                    } else {
                      _startCompassTracking(delay: Duration.zero);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _compassActive
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _compassActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.explore_rounded,
                          size: 14,
                          color: _compassActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _compassActive ? 'Compass ON' : 'Compass OFF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _compassActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_showLegend)
              Positioned(
                left: 16,
                bottom: 16,
                child: _MapLegend(
                  onHide: () => setState(() => _showLegend = false),
                ),
              ),

            if (!_showLegend)
              Positioned(
                left: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  onPressed: () => setState(() => _showLegend = true),
                  backgroundColor: theme.colorScheme.surface,
                  child: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
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
          ],
        );
      },
    );
  }

  Widget _buildMarker(
    double x,
    double y,
    double scaleX,
    double scaleY,
    double offsetX,
    double offsetY,
    double zoom,
    double rotation,
    double displayWidth,
    double displayHeight, {
    bool isUser = false,
    bool isPOI = false,
    bool isTarget = false,
    double angle = 0.0,
    String? name,
    DestinationEntity? destination,
  }) {
    final matrix = _transformationController.value;
    final baseX = x * scaleX + offsetX;
    final baseY = y * scaleY + offsetY;

    // To handle rotation, we need to transform the point around the center of the map
    final mapCenter = Offset(
      offsetX + displayWidth / 2,
      offsetY + displayHeight / 2,
    );
    final relativePoint = Offset(baseX, baseY) - mapCenter;

    // Rotate point around map center (CCW convention matches Transform.rotate
    // when rotation values are negated, which is how _manualRotation is stored)
    final cosR = math.cos(rotation);
    final sinR = math.sin(rotation);
    final rotatedX = relativePoint.dx * cosR - relativePoint.dy * sinR;
    final rotatedY = relativePoint.dx * sinR + relativePoint.dy * cosR;

    final finalBasePoint = Offset(rotatedX, rotatedY) + mapCenter;
    final pos = MatrixUtils.transformPoint(matrix, finalBasePoint);

    if (isUser) {
      final size = (24.0 * zoom).clamp(4.0, 72.0);
      return Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        child: UserPositionMarker(
          size: size,
          // Arrow is glued to the map: heading + full map rotation so it spins with the map
          orientationDegrees: (angle + 90) + (rotation * 180 / math.pi),
        ),
      );
    }

    if (isTarget) {
      final size = (24.0 * zoom).clamp(4.0, 72.0);
      return Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        child: DestinationFlagMarker(size: size),
      );
    }

    // POI
    final size = (12.0 * zoom).clamp(1.5, 40.0);
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

class _MapLegend extends StatelessWidget {
  final VoidCallback onHide;
  const _MapLegend({required this.onHide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Legend',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: onHide,
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LegendItem(
            color: Colors.green,
            icon: Icons.navigation,
            label: 'Your Position',
          ),
          _LegendItem(
            color: const Color(0xFFEA4335),
            icon: Icons.flag,
            label: 'Destination',
          ),
          _LegendItem(
            color: const Color(0xFFEA4335),
            icon: Icons.place,
            label: 'POI / Landmark',
          ),
          _LegendItem(
            color: const Color(0xFF2196F3),
            icon: Icons.horizontal_rule,
            label: 'Route Path',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendItem({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
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

    final path = Path();
    path.moveTo(coords.first.dx * scaleX, coords.first.dy * scaleY);

    // Simple smoothing: if a point is too close to previous, skip it
    Offset last = coords.first;
    for (var i = 1; i < coords.length; i++) {
      final current = coords[i];
      if ((current - last).distance > 2.0) {
        path.lineTo(current.dx * scaleX, current.dy * scaleY);
        last = current;
      }
    }

    final pathMetrics = path.computeMetrics().isNotEmpty
        ? path.computeMetrics().first
        : null;
    if (pathMetrics == null) return;

    // 1. Outer glow/shadow
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 2. White border for contrast (The 'Style' user loves)
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = Colors.white
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // 3. Main gradient path - segmented for the 'authentic' look
    const segmentCount = 40;
    final pathLength = pathMetrics.length;
    for (int i = 0; i < segmentCount; i++) {
      final start = i / segmentCount;
      final end = (i + 1) / segmentCount;
      final segmentPath = pathMetrics.extractPath(
        start * pathLength,
        end * pathLength,
      );

      final t = i / segmentCount;
      final segmentColor = Color.lerp(
        const Color(0xFF4FC3F7), // Light blue start
        const Color(0xFF2196F3), // Deep blue end
        t,
      )!;

      canvas.drawPath(
        segmentPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = segmentColor
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4. Animated Dashes
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.6);

    const dashLen = 8.0, gapLen = 12.0;
    double dist = (animationValue * 30) % (dashLen + gapLen);
    while (dist < pathLength) {
      canvas.drawPath(pathMetrics.extractPath(dist, dist + dashLen), dashPaint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.animationValue != animationValue || old.coords != coords;
}
