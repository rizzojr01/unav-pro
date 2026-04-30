import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzy/fuzzy.dart';

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
  // Live compass heading (0=North CW) streamed directly from FlutterCompass.
  // This is the primary source for real-time map rotation.
  final double? liveCompassHeading;
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
    this.liveCompassHeading,
    this.apiInitialHeading,
    this.capturedReferenceHeading,
    this.headingAtStart,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  late AnimationController _routeAnimationController;
  late AnimationController _rotationAnimationController;
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

  // Last heading (degrees) that was actually applied to the map matrix.
  // Used to suppress small sensor noise — only rotate when the change exceeds
  // the dead-zone threshold.
  double? _lastAppliedHeading;
  static const double _rotationDeadZoneDeg = 2.0;

  // Smooth rotation animation state
  double? _targetRotationRadians;
  double? _currentRotationRadians;
  
  // Cached pan offset to preserve during rotation animation
  Offset? _cachedPanOffset;
  double? _cachedScale;
  
  // Continuous smooth animation parameters
  double _smoothRotationVelocity = 0.0; // rad/ms
  DateTime? _lastRotationUpdateTime;
  
  // Track if user is manually interacting (panning/zooming)
  Matrix4? _lastTransformMatrix;

  String _calculateDeltaString() {
    if (widget.headingAtStart == null ||
        widget.capturedReferenceHeading == null) {
      if (widget.headingAtStart == null &&
          widget.capturedReferenceHeading == null)
        return "N/A (Both Null)";
      if (widget.headingAtStart == null) return "N/A (Plot Null)";
      return "N/A (Ref Null)";
    }
    double d = widget.headingAtStart! - widget.capturedReferenceHeading!;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _routeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _rotationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

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
      _lastAppliedHeading =
          null; // reset so first rotation after floor change always applies
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

    // Real-time rotation: trigger when the live compass value changes by more
    // than the dead-zone. We track the raw compass value for the threshold
    // check — the actual rotation matrix is always computed delta-only inside
    // _getRotationRadians(), so no absolute heading ever reaches the matrix.
    final newCompass =
        widget.liveCompassHeading ?? widget.arRawHeading ?? widget.userHeading;
    if (newCompass != null && _imageSize != null) {
      final last = _lastAppliedHeading;
      final double change;
      if (last == null) {
        change = 360.0; // first reading — always apply
      } else {
        double d = (newCompass - last).abs() % 360.0;
        if (d > 180.0) d = 360.0 - d;
        change = d;
      }

      if (change >= _rotationDeadZoneDeg) {
        _lastAppliedHeading = newCompass;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;

          if (_isAutoCentered) {
            _recenterOnUser(
              box.size,
              _imageSize!,
              initialZoom: _transformationController.value.getMaxScaleOnAxis(),
              animate: false,
            );
          } else {
            _updateRotationOnly(box.size, _imageSize!);
          }
        });
      }
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
    _rotationAnimationController.dispose();
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

  /// Returns the rotation angle in radians to apply to the map matrix.
  ///
  /// ALWAYS delta-only. Never uses absolute heading values.
  ///
  /// formula: rotation = -(backendAng + delta + 90°)
  ///
  ///   backendAng = apiInitialHeading  (0=East CW, floorplan-space)
  ///   delta      = compassNow - compassAtCapture  (normalized ±180°)
  ///
  /// When delta=0 (user hasn't moved since capture) the map sits at the
  /// initial backend orientation. Every degree the user rotates clockwise
  /// adds +1° to delta, rotating the map by exactly that amount.
  double _getRotationRadians() {
    final backendAng = widget.apiInitialHeading;
    final refHead = widget.capturedReferenceHeading; // compass at shutter

    // Priority 1: AR pose heading — already in floorplan space (0=East, CW).
    // Most accurate: no magnetic interference, continuous once AR is running.
    // Formula: -(arHeading + 90°) rotates map so camera's forward faces up.
    if (widget.arRawHeading != null) {
      return -(widget.arRawHeading! + 90.0) * (math.pi / 180.0);
    }

    // Priority 2: live compass delta (fallback before AR localizes).
    if (widget.liveCompassHeading != null &&
        refHead != null &&
        backendAng != null) {
      double delta = widget.liveCompassHeading! - refHead;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      return -(backendAng + delta + 90.0) * (math.pi / 180.0);
    }

    // Priority 3: static delta (headingAtStart - capturedReferenceHeading).
    // Used before compass fires. Correct for initial placement after loading.
    if (backendAng != null &&
        refHead != null &&
        widget.headingAtStart != null) {
      double delta = widget.headingAtStart! - refHead;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      return -(backendAng + delta + 90.0) * (math.pi / 180.0);
    }

    // Priority 4: no delta available — show map at backend ang, no user offset.
    if (backendAng != null) {
      return -(backendAng + 90.0) * (math.pi / 180.0);
    }

    return 0.0;
  }

  void _initializeView(Size containerSize, Size imageSize) {
    if (_hasInitializedView || !widget.autoCenterOnUser) return;
    _hasInitializedView = true;
    
    // Set initial rotation and pan values so the very first frame of the
    // continuous rotation loop has a correct baseline.
    final initialRotation = _getRotationRadians();
    _currentRotationRadians = initialRotation;
    _targetRotationRadians = initialRotation;
    
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

    // Use current heading for rotation so recenter also respects orientation.
    // Returns 0.0 (north-up) when no heading data is available yet.
    final double rotation = _getRotationRadians();

    final targetMatrix = Matrix4.identity()
      ..translate(containerSize.width / 2, containerSize.height * 0.5)
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

    final targetRotation = _getRotationRadians();
    _targetRotationRadians = targetRotation;
    
    // Check if user panned (transformation matrix changed by something other than our rotation)
    final currentMatrix = _transformationController.value;
    
    // Detect transformation changes by comparing with our last known update
    if (_lastTransformMatrix != null) {
      final oldS = _lastTransformMatrix!.storage;
      final newS = currentMatrix.storage;
      
      // Calculate user's screen position in CURRENT matrix
      // (This reflects where they ARE right now, including any manual pan)
      final userScreenPos = MatrixUtils.transformPoint(
        currentMatrix,
        Offset(userDisplayX, userDisplayY),
      );

      // Detect manual transformation changes (translation or scale)
      bool manuallyChanged = false;
      final translationDiff = (oldS[12] - newS[12]).abs() + (oldS[13] - newS[13]).abs();
      
      if (translationDiff > 0.5) {
        manuallyChanged = true;
      }
      
      if (manuallyChanged) {
        // User panned/zoomed - update cached values to track their new screen position
        _cachedScale = currentMatrix.getMaxScaleOnAxis();
        _cachedPanOffset = userScreenPos;
      }
    }
    
    // Cache the current pan offset and scale (on first call or if not yet set)
    if (_cachedPanOffset == null || _cachedScale == null) {
      _cachedScale = currentMatrix.getMaxScaleOnAxis();
      _cachedPanOffset = MatrixUtils.transformPoint(
        currentMatrix,
        Offset(userDisplayX, userDisplayY),
      );
    }

    // Initialize current rotation on first call IF it hasn't been set by _initializeView
    _currentRotationRadians ??= targetRotation;
    
    _lastTransformMatrix = currentMatrix;


    // Set up continuous animation that runs every frame
    if (!_rotationAnimationController.isAnimating) {
      _lastRotationUpdateTime = DateTime.now();
      
      _rotationAnimationController.removeListener(() {});
      _rotationAnimationController.addListener(() {
        _applyRotationUpdate(userDisplayX, userDisplayY);
      });
      
      // Run animation indefinitely (we control it manually)
      _rotationAnimationController.repeat();
    }
  }

  void _applyRotationUpdate(double userDisplayX, double userDisplayY) {
    if (!mounted || _targetRotationRadians == null || _cachedPanOffset == null || _cachedScale == null) {
      return;
    }

    // If InteractiveViewer changed the matrix since our last write (user panned
    // or pinch-zoomed), capture the new pan/scale before we overwrite it.
    final currentMatrix = _transformationController.value;
    if (_lastTransformMatrix != null) {
      final oldS = _lastTransformMatrix!.storage;
      final newS = currentMatrix.storage;
      final translationDiff =
          (oldS[12] - newS[12]).abs() + (oldS[13] - newS[13]).abs();
      final scaleDiff =
          (currentMatrix.getMaxScaleOnAxis() - _cachedScale!).abs();
      if (translationDiff > 0.01 || scaleDiff > 0.01) {
        _cachedScale = currentMatrix.getMaxScaleOnAxis();
        _cachedPanOffset = MatrixUtils.transformPoint(
          currentMatrix,
          Offset(userDisplayX, userDisplayY),
        );
      }
    }

    final now = DateTime.now();
    final timeDelta = _lastRotationUpdateTime == null
        ? 0
        : now.difference(_lastRotationUpdateTime!).inMilliseconds;
    _lastRotationUpdateTime = now;

    final currentRot = _currentRotationRadians!;
    final targetRot = _targetRotationRadians!;

    // Calculate angle difference with wrap-around
    var angleDiff = targetRot - currentRot;
    if (angleDiff > math.pi) angleDiff -= 2 * math.pi;
    if (angleDiff < -math.pi) angleDiff += 2 * math.pi;

    // Smoothly interpolate toward target at max 500 deg/sec
    const maxDegreesPerSec = 500.0;
    const maxRadiansPerSec = maxDegreesPerSec * math.pi / 180.0;
    final maxRadiansPerMs = maxRadiansPerSec / 1000.0;
    final maxChange = maxRadiansPerMs * timeDelta;

    double newRot;
    if (angleDiff.abs() < maxChange) {
      // Close enough to target, snap to it
      newRot = targetRot;
    } else {
      // Move toward target at max speed
      newRot = currentRot + (angleDiff.sign * maxChange);
    }

    _currentRotationRadians = newRot;

    // Build new matrix using cached pan offset
    final newMatrix = Matrix4.identity()
      ..translate(_cachedPanOffset!.dx, _cachedPanOffset!.dy)
      ..rotateZ(newRot)
      ..translate(-userDisplayX * _cachedScale!, -userDisplayY * _cachedScale!)
      ..scale(_cachedScale!);

    _transformationController.value = newMatrix;
    _lastTransformMatrix = newMatrix;
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
                              pathCoords = arState.trackedPath;
                            } else {
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
                        'Map Rot: ${(_transformationController.value.storage[1] != 0 || _transformationController.value.storage[0] != 0) ? (math.atan2(_transformationController.value.storage[1], _transformationController.value.storage[0]) * (180.0 / math.pi)).toStringAsFixed(1) : "0.0"}°',
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
                      const SizedBox(height: 4),
                      Text(
                        'API Ang (Used for AR): ${widget.apiInitialHeading?.toStringAsFixed(1) ?? "N/A"}°',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

      // The map rotates so the user's forward direction always faces screen-up.
      // Therefore the user arrow must always point straight up (0°) on screen —
      // no counter-rotation needed.
      const markerHeading = 0.0;

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
