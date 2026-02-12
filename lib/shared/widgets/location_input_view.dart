import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../injection.dart';
import '../services/floor_plan_cache_service.dart';
import '../services/location_config_service.dart';
import 'custom_snackbar.dart' as snackbar;
import 'floor_plan_selector_widget.dart';

class LocationInputView extends StatefulWidget {
  final TabController tabController;
  final Function(String path) onImageCaptured;
  final Function(double x, double y) onLocationSelected;
  final String floorPlanConfirmText;

  const LocationInputView({
    super.key,
    required this.tabController,
    required this.onImageCaptured,
    required this.onLocationSelected,
    this.floorPlanConfirmText = 'Set My Location',
  });

  @override
  State<LocationInputView> createState() => _LocationInputViewState();
}

class _LocationInputViewState extends State<LocationInputView> {
  CameraController? _controller;
  CameraMacOSController? _macOSController;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
            if (mounted) {
              widget.onImageCaptured(file.path);
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
      if (mounted) {
        widget.onImageCaptured(image.path);
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
            const _CameraGuidance(),
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
        const _CameraGuidance(),

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
    final floorPlanCacheService = getIt<FloorPlanCacheService>();
    final locationConfig = getIt<LocationConfigService>();

    final cachedFloorPlan = floorPlanCacheService.getCachedFloorPlanBase64(
      place: locationConfig.place,
      building: locationConfig.building,
      floor: locationConfig.floor,
    );

    return FloorPlanSelectorWidget(
      base64FloorPlan: cachedFloorPlan,
      onLocationSelected: widget.onLocationSelected,
      confirmButtonText: widget.floorPlanConfirmText,
    );
  }
}

class _CameraGuidance extends StatelessWidget {
  const _CameraGuidance();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top 20% Overlay - CEILING
        Expanded(
          flex: 20,
          child: _GuidanceSection(
            label: 'CEILING',
            color: Colors.white.withValues(alpha: 0.03),
            showBottomDivider: true,
          ),
        ),
        // Middle 60% Overlay - PATH
        Expanded(
          flex: 60,
          child: _GuidanceSection(
            label: 'PATH',
            color: Colors.transparent,
            showBottomDivider: true,
          ),
        ),
        // Bottom 20% Overlay - FLOOR
        Expanded(
          flex: 20,
          child: _GuidanceSection(
            label: 'FLOOR',
            color: Colors.black.withValues(alpha: 0.08),
            showBottomDivider: false,
          ),
        ),
      ],
    );
  }
}

class _GuidanceSection extends StatelessWidget {
  final String label;
  final Color color;
  final bool showBottomDivider;

  const _GuidanceSection({
    required this.label,
    required this.color,
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              )
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          if (showBottomDivider)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
