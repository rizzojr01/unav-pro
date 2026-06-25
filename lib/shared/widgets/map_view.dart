import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_sense/shared/services/location_config_service.dart';

import '../../features/ar_navigation/presentation/bloc/ar_navigation_bloc.dart';
import '../../features/ar_navigation/presentation/bloc/ar_navigation_state.dart';
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
  final VoidCallback? onRelocalize;
  final bool autoCenterOnUser;
  final String? currentFloor;
  final bool isCheckpoint;
  final double mapControlsRightOffset;

  final double? userHeading;
  final double? arRawHeading;
  final double? arTravelDistance;
  final double? arConfidence;
  final double? apiInitialHeading;
  final double? capturedReferenceHeading;
  final double? headingAtStart;

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
    this.arTravelDistance,
    this.arConfidence,
    this.apiInitialHeading,
    this.capturedReferenceHeading,
    this.headingAtStart,
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
  final bool _isAutoCentered = true;
  final TextEditingController _searchController = TextEditingController();
  List<DestinationEntity> _filteredDestinations = [];

  // Rotation state — ported from main's `_manualRotation` model.
  // Driven by the AR-derived heading (userHeading) or the API fallback
  // (apiInitialHeading). InteractiveViewer wraps Transform.rotate so the
  // pan/zoom matrix operates on the already-rotated content. Whenever the
  // rotation target changes we compensate the IV matrix via
  // `_applyManualRotation` so the user dot stays pinned to its on-screen
  // position across the change.
  double _manualRotation = 0.0;

  String _calculateDeltaString() {
    if (widget.userHeading == null || widget.apiInitialHeading == null) {
      return "N/A";
    }
    double delta = widget.userHeading! - widget.apiInitialHeading!;
    var result = delta % 360.0;
    if (result < -180.0) result += 360.0;
    if (result >= 180.0) result -= 360.0;
    return result.toStringAsFixed(1);
  }

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

  /// Target rotation derived from heading: −(h + 90)·π/180 puts the
  /// user's forward direction at screen top. Mirrors main's convention.
  double get _targetRotation {
    final h = widget.userHeading ?? widget.apiInitialHeading;
    if (h == null) return 0.0;
    return -(h + 90.0) * math.pi / 180.0;
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floorPlanBase64 != widget.floorPlanBase64) {
      setState(() {
        _imageSize = null;
        _hasInitializedView = false;
      });
      _decodeFloorPlan();
    }
    if (oldWidget.destinations != widget.destinations) {
      _filteredDestinations = widget.destinations;
    }

    // First heading update: seed rotation directly, then recenter.
    // No shift-math needed because we're snapping the user to screen mid
    // at the same moment we set the rotation baseline.
    final hadHeading =
        oldWidget.userHeading != null || oldWidget.apiInitialHeading != null;
    final hasHeading =
        widget.userHeading != null || widget.apiInitialHeading != null;
    if (!hadHeading && hasHeading && _imageSize != null) {
      _manualRotation = _targetRotation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        _recenterOnUser(box.size, _imageSize!, initialZoom: 3.5);
      });
    }

    // Subsequent heading updates: pivot rotation around the user's
    // on-screen position via `_applyManualRotation` (translates the IV
    // matrix so the user stays pinned across the rotation change).
    final newRot = _targetRotation;
    if (hadHeading &&
        hasHeading &&
        _imageSize != null &&
        (newRot - _manualRotation).abs() > 1e-6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyManualRotation(newRot);
      });
    }

    // Continuous follow: user walked far enough that we want to pull
    // them back toward screen centre. Preserves current zoom + rotation.
    final oldCoords = _coordsFromLocation(oldWidget.userLocation);
    final newCoords = _coordsFromLocation(widget.userLocation);
    if (oldCoords != null &&
        newCoords != null &&
        (oldCoords - newCoords).distance > 0.5 &&
        _imageSize != null &&
        widget.autoCenterOnUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        _recenterOnUser(box.size, _imageSize!);
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
        _recenterOnUser(box.size, _imageSize!, initialZoom: 3.5);
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

  Offset? _coordsFromLocation(dynamic loc) {
    if (loc == null) return null;
    try {
      return Offset((loc.x as num).toDouble(), (loc.y as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  /// Ported verbatim from main: translate the IV matrix so the user's
  /// on-screen position stays put across a rotation change. Computes the
  /// user's projected position under the old and new rotation around the
  /// container centre, then shifts the IV matrix by the delta.
  void _applyManualRotation(double newRotation) {
    if (_imageSize == null) {
      setState(() => _manualRotation = newRotation);
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      setState(() => _manualRotation = newRotation);
      return;
    }

    final cSize = box.size;
    final iAR = _imageSize!.width / _imageSize!.height;
    final cAR = cSize.width / cSize.height;
    double dispW, dispH;
    if (iAR > cAR) {
      dispW = cSize.width;
      dispH = cSize.width / iAR;
    } else {
      dispH = cSize.height;
      dispW = cSize.height * iAR;
    }
    final sX = dispW / _imageSize!.width;
    final sY = dispH / _imageSize!.height;
    final offX = (cSize.width - dispW) / 2;
    final offY = (cSize.height - dispH) / 2;
    final userPos = _getUserCoords();

    final userCX = userPos.dx * sX + offX;
    final userCY = userPos.dy * sY + offY;
    final cx = cSize.width / 2;
    final cy = cSize.height / 2;
    final dxU = userCX - cx;
    final dyU = userCY - cy;

    final cosOld = math.cos(_manualRotation);
    final sinOld = math.sin(_manualRotation);
    final oldX = cx + dxU * cosOld - dyU * sinOld;
    final oldY = cy + dxU * sinOld + dyU * cosOld;

    final cosNew = math.cos(newRotation);
    final sinNew = math.sin(newRotation);
    final newX = cx + dxU * cosNew - dyU * sinNew;
    final newY = cy + dxU * sinNew + dyU * cosNew;

    final shiftX = oldX - newX;
    final shiftY = oldY - newY;

    final newMatrix = _transformationController.value.clone()
      ..translateByDouble(shiftX, shiftY, 0, 1);

    setState(() {
      _manualRotation = newRotation;
      _transformationController.value = newMatrix;
    });
  }

  /// Ported from main: places the user at horizontally-centered, 75%-down
  /// in screen space at [initialZoom]. Accounts for the current
  /// `_manualRotation` since the IV wraps Transform.rotate — the user's
  /// post-rotation position is what we need to centre.
  void _recenterOnUser(
    Size containerSize,
    Size imageSize, {
    double initialZoom = 2.5,
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

    final cx = containerSize.width / 2;
    final cy = containerSize.height / 2;
    final dx = userDisplayX - cx;
    final dy = userDisplayY - cy;
    final cosA = math.cos(_manualRotation);
    final sinA = math.sin(_manualRotation);
    final rotatedUserX = cx + dx * cosA - dy * sinA;
    final rotatedUserY = cy + dx * sinA + dy * cosA;

    // Target: horizontally centered, 75% down (Google Maps style).
    final targetX = containerSize.width / 2;
    final targetY = containerSize.height * 0.75;

    final translateX = targetX - rotatedUserX * initialZoom;
    final translateY = targetY - rotatedUserY * initialZoom;

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(initialZoom, initialZoom, initialZoom, 1);
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
    _manualRotation = _targetRotation;
    _recenterOnUser(containerSize, imageSize, initialZoom: 3.5);
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
        final rotationAngle = _manualRotation;

        return Stack(
          children: [
            // Main structure (ported from main):
            //   InteractiveViewer ← handles pan/zoom on the whole rotated map.
            //     Transform.rotate(_manualRotation) ← rotates floorplan + route.
            //       Center → SizedBox → Stack(image + route painter).
            // Markers live in the outer Stack and replicate the rotation
            // around the display centre via _buildMarker so they stay
            // glued to the right floorplan coordinates without inheriting
            // the InteractiveViewer's gesture surface.
            InteractiveViewer(
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
                        if (widget.route != null)
                          BlocBuilder<ArNavigationBloc, ArNavigationState>(
                            builder: (context, arState) {
                              final fullRouteCoords = widget.route!.steps
                                  .expand(
                                    (s) => [
                                      Offset(s.from.x, s.from.y),
                                      Offset(s.to.x, s.to.y),
                                    ],
                                  )
                                  .toList();

                              List<Offset> activePathCoords;
                              if (arState is ArNavigationTracking &&
                                  arState.trackedPath.isNotEmpty) {
                                activePathCoords = arState.trackedPath;
                              } else {
                                activePathCoords = fullRouteCoords;
                              }

                              return ValueListenableBuilder<bool>(
                                valueListenable:
                                    GetIt.I<LocationConfigService>()
                                        .snapToRouteNotifier,
                                builder: (context, snapEnabled, _) =>
                                    AnimatedBuilder(
                                  animation: _routeAnimationController,
                                  builder: (context, _) => CustomPaint(
                                    size: Size(displayWidth, displayHeight),
                                    painter: RoutePainter(
                                      coords: activePathCoords,
                                      networkSegments: snapEnabled
                                          ? widget.route!.routeNetworkSegments
                                          : const [],
                                      scaleX: scaleX,
                                      scaleY: scaleY,
                                      animationValue:
                                          _routeAnimationController.value,
                                    ),
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
            ),

            // Marker overlay (outside the IV). Each marker manually
            // replicates the same rotation that Transform.rotate applies
            // inside the IV, then projects through the IV matrix to land
            // at the correct screen position.
            AnimatedBuilder(
              animation: _transformationController,
              builder: (context, _) {
                final zoom =
                    _transformationController.value.getMaxScaleOnAxis();
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
                        rotationAngle,
                        displayWidth,
                        displayHeight,
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
                        rotationAngle,
                        displayWidth,
                        displayHeight,
                        isTarget: true,
                      ),
                    if (widget.route != null && widget.currentFloor != null)
                      ..._transitionsForCurrentFloor().map(
                        (t) => _buildMarker(
                          t.exitPoint.dx,
                          t.exitPoint.dy,
                          scaleX,
                          scaleY,
                          centerOffsetX,
                          centerOffsetY,
                          zoom,
                          rotationAngle,
                          displayWidth,
                          displayHeight,
                          isTransition: true,
                          transitionTargetFloor: t.toFloor,
                        ),
                      ),
                    _buildMarker(
                      _getUserCoords().dx,
                      _getUserCoords().dy,
                      scaleX,
                      scaleY,
                      centerOffsetX,
                      centerOffsetY,
                      zoom,
                      rotationAngle,
                      displayWidth,
                      displayHeight,
                      isUser: true,
                      isCheckpoint: widget.isCheckpoint,
                    ),
                  ],
                );
              },
            ),

            // Debug Info Panel — gated by the debug banner toggle in profile settings.
            Positioned(
              left: 16,
              top: 100,
              child: ValueListenableBuilder<bool>(
                valueListenable:
                    GetIt.instance<LocationConfigService>().debugBannerNotifier,
                builder: (_, showDebug, __) {
                  if (!showDebug) return const SizedBox.shrink();
                  return IgnorePointer(
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
                            'AR Track Len: ${widget.arTravelDistance?.toStringAsFixed(1) ?? "0.0"} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'AR Conf: ${widget.arConfidence?.toStringAsFixed(2) ?? "N/A"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Ref Head: ${widget.capturedReferenceHeading?.toStringAsFixed(1) ?? "N/A"}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Plot Head: ${widget.headingAtStart?.toStringAsFixed(1) ?? "N/A"}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Delta: ${_calculateDeltaString()}°',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Map Rot: ${(_manualRotation * 180.0 / math.pi).toStringAsFixed(1)}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Auto-Center: $_isAutoCentered',
                            style: TextStyle(
                              color:
                                  _isAutoCentered ? Colors.green : Colors.red,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'API Ang (Used for AR): ${widget.apiInitialHeading?.toStringAsFixed(1) ?? "N/A"}°',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ValueListenableBuilder<double>(
                            valueListenable: GetIt.I<LocationConfigService>()
                                .arHeadingOffsetDegNotifier,
                            builder: (context, offset, _) => Text(
                              'AR Heading Offset: ${offset.toStringAsFixed(1)}°',
                              style: const TextStyle(
                                color: Colors.lightGreenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            MapControls(
              right: 16 + widget.mapControlsRightOffset,
              onSearch: () => setState(() => _isSearching = true),
              onReset: () {
                _recenterOnUser(
                  containerSize,
                  _imageSize!,
                  initialZoom: 3.5,
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
          ],
        );
      },
    );
  }

  /// Ported from main: rotates the floorplan coordinate around the
  /// display centre by `rotation` (matching the inner Transform.rotate),
  /// then projects through the IV matrix to get the screen pixel where
  /// the marker should sit.
  List<FloorTransition> _transitionsForCurrentFloor() {
    final route = widget.route;
    if (route == null) return const [];
    final current = widget.currentFloor;
    if (current == null) return const [];
    String norm(String f) =>
        f.replaceAll('_floor', '').replaceAll('_', '').trim().toLowerCase();
    final target = norm(current);
    return route.floorTransitions
        .where((t) => norm(t.fromFloor) == target)
        .toList();
  }

  Widget _buildMarker(
    double x,
    double y,
    double sX,
    double sY,
    double offX,
    double offY,
    double zoom,
    double rotation,
    double displayWidth,
    double displayHeight, {
    bool isUser = false,
    bool isPOI = false,
    bool isTarget = false,
    bool isCheckpoint = false,
    bool isTransition = false,
    String? transitionTargetFloor,
    String? name,
    DestinationEntity? destination,
  }) {
    final matrix = _transformationController.value;
    final baseX = x * sX + offX;
    final baseY = y * sY + offY;

    final mapCenter = Offset(
      offX + displayWidth / 2,
      offY + displayHeight / 2,
    );
    final relativePoint = Offset(baseX, baseY) - mapCenter;

    final cosR = math.cos(rotation);
    final sinR = math.sin(rotation);
    final rotatedX = relativePoint.dx * cosR - relativePoint.dy * sinR;
    final rotatedY = relativePoint.dx * sinR + relativePoint.dy * cosR;

    final finalBasePoint = Offset(rotatedX, rotatedY) + mapCenter;
    if (finalBasePoint.dx.isNaN ||
        finalBasePoint.dy.isNaN ||
        finalBasePoint.dx.isInfinite ||
        finalBasePoint.dy.isInfinite) {
      return const SizedBox.shrink();
    }

    final pos = MatrixUtils.transformPoint(matrix, finalBasePoint);
    if (pos.dx.isNaN ||
        pos.dy.isNaN ||
        pos.dx.isInfinite ||
        pos.dy.isInfinite) {
      return const SizedBox.shrink();
    }

    if (isUser) {
      final size = ((isCheckpoint ? 12.0 : 16.0) * zoom).clamp(4.0, 48.0);
      // Map already rotates so the user's forward direction faces screen up
      // (via _manualRotation = −(h+90)°). Arrow points 0° → straight up.
      return Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        child: UserPositionMarker(
          size: size,
          isCheckpoint: isCheckpoint,
          heading: 0.0,
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

    if (isTransition) {
      final iconSize = (18.0 * zoom).clamp(14.0, 44.0);
      final boxSize = iconSize + 8;
      return Positioned(
        left: pos.dx - boxSize / 2,
        top: pos.dy - boxSize / 2,
        child: Tooltip(
          message: transitionTargetFloor != null
              ? 'Floor change → ${transitionTargetFloor.replaceAll('_floor', '')}'
              : 'Floor change',
          child: Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.stairs,
              color: Colors.white,
              size: iconSize * 0.7,
            ),
          ),
        ),
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
  final List<(Offset, Offset)> networkSegments;
  final double scaleX, scaleY;
  final double animationValue;
  final double opacity;

  RoutePainter({
    required this.coords,
    required this.scaleX,
    required this.scaleY,
    required this.animationValue,
    this.networkSegments = const [],
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (networkSegments.isNotEmpty) {
      final networkPaint = Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.35 * opacity)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final (a, b) in networkSegments) {
        canvas.drawLine(
          Offset(a.dx * scaleX, a.dy * scaleY),
          Offset(b.dx * scaleX, b.dy * scaleY),
          networkPaint,
        );
      }
    }
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

    final metrics =
        path.computeMetrics().isNotEmpty ? path.computeMetrics().first : null;
    if (metrics == null) return;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.15 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: opacity)
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
              .withValues(alpha: opacity)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.6 * opacity);
    const dashLen = 8.0, gapLen = 12.0;
    double dist = (animationValue * 30) % (dashLen + gapLen);
    while (dist < len) {
      canvas.drawPath(metrics.extractPath(dist, dist + dashLen), dashPaint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.animationValue != animationValue ||
      old.coords != coords ||
      old.networkSegments != networkSegments ||
      old.opacity != opacity;
}
