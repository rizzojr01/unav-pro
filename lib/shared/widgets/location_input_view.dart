import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import '../../core/utils/logger.dart';

import '../../features/destination/presentation/bloc/floor_map_bloc.dart';
import '../../features/destination/presentation/bloc/floor_map_event.dart';
import '../../features/destination/presentation/bloc/floor_map_state.dart';

import '../../injection.dart';
import '../services/location_config_service.dart';
import 'custom_snackbar.dart' as snackbar;
import 'floor_plan_selector_widget.dart';

class LocationInputView extends StatefulWidget {
  final TabController tabController;
  final Function(String path, String floor) onImageCaptured;
  final Function(double x, double y, String floor) onLocationSelected;
  final String floorPlanConfirmText;
  final String? initialFloor;

  const LocationInputView({
    super.key,
    required this.tabController,
    required this.onImageCaptured,
    required this.onLocationSelected,
    this.floorPlanConfirmText = 'Set My Location',
    this.initialFloor,
  });

  @override
  State<LocationInputView> createState() => _LocationInputViewState();
}

class _LocationInputViewState extends State<LocationInputView> {
  CameraController? _controller;
  CameraMacOSController? _macOSController;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _showGuidance = true;
  String? _errorMessage;

  final _logger = getIt<AppLogger>();

  late FloorMapBloc _floorMapBloc;
  FixedExtentScrollController? _floorController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _floorMapBloc = FloorMapBloc()
      ..add(FloorMapInitialized(initialFloor: widget.initialFloor));
  }

  void _syncFloorController(List<String> floors, String selectedFloor) {
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
  void dispose() {
    _controller?.dispose();
    _floorController?.dispose();
    _floorMapBloc.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      if (Platform.isMacOS) {
        if (mounted) setState(() => _errorMessage = null);
        return;
      }

      if (mounted) setState(() => _errorMessage = null);

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'No cameras found on this device.';
          });
        }
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Error initializing camera: $e';
        });
      }
    }
  }

  Future<bool> _isImageClear(String path) async {
    // Placeholder for image quality check (focus/blur/motion)
    // In a production app, we would use a native plugin or TFLite model
    // to check Laplacian variance or similar metrics.
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate processing
    return true; // Auto-accepting for now
  }

  Future<void> _captureImage() async {
    if (Platform.isMacOS) {
      if (_macOSController != null && !_isCapturing) {
        setState(() => _isCapturing = true);
        try {
          final result = await _macOSController!.takePicture();
          if (result != null && result.bytes != null) {
            final tempDir = await getTemporaryDirectory();
            final file = File(
              '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await file.writeAsBytes(result.bytes!);

            final isClear = await _isImageClear(file.path);
            if (mounted) {
              if (isClear) {
                String selectedFloor = getIt<LocationConfigService>().floor;
                if (_floorMapBloc.state is FloorMapReady) {
                  selectedFloor =
                      (_floorMapBloc.state as FloorMapReady).selectedFloor;
                }
                _logger.info('Image Captured');
                widget.onImageCaptured(file.path, selectedFloor);
              } else {
                snackbar.CustomSnackBar.show(
                  context,
                  message: 'Image is blurry. Please hold steady and try again.',
                  type: snackbar.SnackBarType.warning,
                );
              }
            }
          }
        } catch (e) {
          if (mounted) {
            snackbar.CustomSnackBar.show(
              context,
              message: 'Failed to capture image: ${e.toString()}',
              type: snackbar.SnackBarType.error,
            );
          }
        } finally {
          if (mounted) setState(() => _isCapturing = false);
        }
      }
      return;
    }

    // Mobile Capture Logic
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      final isClear = await _isImageClear(image.path);

      if (mounted) {
        if (isClear) {
          String selectedFloor = getIt<LocationConfigService>().floor;
          if (_floorMapBloc.state is FloorMapReady) {
            selectedFloor =
                (_floorMapBloc.state as FloorMapReady).selectedFloor;
          }
          _logger.info('Image Captured');
          widget.onImageCaptured(image.path, selectedFloor);
        } else {
          snackbar.CustomSnackBar.show(
            context,
            message: 'Image is blurry. Please hold steady and try again.',
            type: snackbar.SnackBarType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        snackbar.CustomSnackBar.show(
          context,
          message: 'Failed to capture image: ${e.toString()}',
          type: snackbar.SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TabBarView(
      controller: widget.tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [_buildCameraTab(theme), _buildFloorPlanTab(theme)],
    );
  }

  Widget _buildCameraTab(ThemeData theme) {
    // macOS Camera View
    if (Platform.isMacOS) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraMacOSView(
            key: GlobalKey(),
            fit: BoxFit.cover,
            cameraMode: CameraMacOSMode.photo,
            onCameraInizialized: (CameraMacOSController controller) {
              if (mounted) {
                setState(() {
                  _macOSController = controller;
                  _isInitializing = false;
                  _errorMessage = null; // Clear any previous error
                });
              }
            },
          ),
          if (_isInitializing) const Center(child: CircularProgressIndicator()),
          if (!_isInitializing) ...[
            _CameraGuidance(
              showGuidance: _showGuidance,
              onToggle: () => setState(() => _showGuidance = !_showGuidance),
            ),
            // Capture Button (Shared UI)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 60), // Spacer for symmetry
                  GestureDetector(
                    onTap: _captureImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.camera_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: 40,
                            ),
                    ),
                  ),
                  const SizedBox(width: 60), // Spacer for symmetry
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Mobile Camera View
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Camera not available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isInitializing = true);
                  _initializeCamera();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera Preview (fullscreen)
        Positioned.fill(child: CameraPreview(_controller!)),

        // 2. Camera Guidance Overlays (CEILING, PATH, FLOOR)
        _CameraGuidance(
          showGuidance: _showGuidance,
          onToggle: () => setState(() => _showGuidance = !_showGuidance),
        ),

        // 3. Capture Button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 60), // Spacer for symmetry
              GestureDetector(
                onTap: _captureImage,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _isCapturing
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Icon(
                          Icons.camera_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 40,
                        ),
                ),
              ),
              const SizedBox(width: 60), // Spacer for symmetry
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloorPlanTab(ThemeData theme) {
    final locationConfig = getIt<LocationConfigService>();

    return BlocProvider.value(
      value: _floorMapBloc,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BlocListener<FloorMapBloc, FloorMapState>(
          listener: (context, state) {
            if (state is FloorMapReady) {
              _syncFloorController(state.availableFloors, state.selectedFloor);
            }
          },
          child: Stack(
            children: [
              BlocBuilder<FloorMapBloc, FloorMapState>(
                builder: (context, state) {
                  if (state is FloorMapLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is FloorMapReady) {
                    return FloorPlanSelectorWidget(
                      base64FloorPlan: state.base64FloorPlan,
                      onLocationSelected: (x, y) =>
                          widget.onLocationSelected(x, y, state.selectedFloor),
                      confirmButtonText: widget.floorPlanConfirmText,
                    );
                  } else if (state is FloorMapError) {
                    return Center(
                      child: Text(
                        'Error: ${state.message}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Rotary Floor Selector (Integrated into the tab)
              if (locationConfig.multiFloorNavigation)
                BlocBuilder<FloorMapBloc, FloorMapState>(
                  builder: (context, state) {
                    if (state is FloorMapReady &&
                        state.availableFloors.isNotEmpty) {
                      _syncFloorController(
                        state.availableFloors,
                        state.selectedFloor,
                      );

                      return Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 44,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withOpacity(
                                    0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    CupertinoPicker(
                                      scrollController: _floorController,
                                      itemExtent: 34,
                                      diameterRatio: 0.9,
                                      squeeze: 1.3,
                                      magnification: 1.1,
                                      useMagnifier: true,
                                      onSelectedItemChanged: (index) {
                                        HapticFeedback.selectionClick();
                                        final newFloor =
                                            state.availableFloors[index];
                                        if (newFloor != state.selectedFloor) {
                                          _floorMapBloc.add(
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
                                                  fontSize: 14,
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

class _CameraGuidance extends StatefulWidget {
  final bool showGuidance;
  final VoidCallback onToggle;

  const _CameraGuidance({required this.showGuidance, required this.onToggle});

  @override
  State<_CameraGuidance> createState() => _CameraGuidanceState();
}

class _CameraGuidanceState extends State<_CameraGuidance> {
  @override
  Widget build(BuildContext context) {
    if (!widget.showGuidance) {
      // Just show the toggle when guidance is hidden
      return Positioned(
        top: 20,
        right: 20,
        child: _GuidanceToggle(showGuidance: false, onToggle: widget.onToggle),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // Top 25% Overlay - CEILING
            Expanded(
              flex: 25,
              child: _GuidanceSection(
                label: 'CEILING',
                description: 'Include 20-30% of ceiling',
                color: Colors.black.withValues(alpha: 0.3),
                showBottomDivider: true,
                alignment: Alignment.topCenter,
              ),
            ),
            // Middle 50% Overlay - PATH
            Expanded(
              flex: 50,
              child: _GuidanceSection(
                label: 'PATH',
                description: 'Keep path clear',
                color: Colors.transparent,
                showBottomDivider: true,
                alignment: Alignment.center,
              ),
            ),
            // Bottom 25% Overlay - FLOOR
            Expanded(
              flex: 25,
              child: _GuidanceSection(
                label: '', // Removed label to avoid overlap with button
                description: '', // Removed description
                color: Colors.black.withValues(alpha: 0.3),
                showBottomDivider: false,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
        // Toggle Button
        Positioned(
          top: 20,
          right: 20,
          child: _GuidanceToggle(showGuidance: true, onToggle: widget.onToggle),
        ),
      ],
    );
  }
}

class _GuidanceToggle extends StatelessWidget {
  final bool showGuidance;
  final VoidCallback onToggle;

  const _GuidanceToggle({required this.showGuidance, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showGuidance ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                showGuidance ? 'Hide Guide' : 'Show Guide',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidanceSection extends StatelessWidget {
  final String label;
  final String description;
  final Color color;
  final bool showBottomDivider;
  final Alignment alignment;

  const _GuidanceSection({
    required this.label,
    required this.description,
    required this.color,
    required this.alignment,
    this.showBottomDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: showBottomDivider
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  width: 2,
                ),
              )
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Align(
              alignment: alignment == Alignment.topCenter
                  ? Alignment.topCenter
                  : (alignment == Alignment.bottomCenter
                        ? Alignment.bottomCenter
                        : Alignment.center),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  if (label.isNotEmpty && description.isNotEmpty)
                    const SizedBox(height: 4),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showBottomDivider)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  Icons.expand_more,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
