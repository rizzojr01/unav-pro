import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import '../../../../shared/services/debug_config_service.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/custom_loading_view.dart';
import '../bloc/locate_me_bloc.dart';
import '../bloc/locate_me_event.dart';
import '../bloc/locate_me_state.dart';
import 'locate_me_floor_plan_page.dart';

class LocateMeCameraPage extends StatefulWidget {
  const LocateMeCameraPage({super.key});

  @override
  State<LocateMeCameraPage> createState() => _LocateMeCameraPageState();
}

class _LocateMeCameraPageState extends State<LocateMeCameraPage> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _showSample = false;

  @override
  void initState() {
    super.initState();
    _checkDebugModeAndInitialize();
  }

  Future<void> _checkDebugModeAndInitialize() async {
    final debugConfig = getIt<DebugConfigService>();

    // If sample image is enabled in debug options, skip camera and use sample directly
    if (debugConfig.useSampleImage) {
      // Small delay to ensure bloc is ready
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        context.read<LocateMeBloc>().add(
          const StartLocalizationWithSampleEvent(),
        );
      }
      return;
    }

    // Otherwise, initialize camera normally
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isInitializing = false);
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
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndLocalize() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      // Use sample image if camera not available
      context.read<LocateMeBloc>().add(
        const StartLocalizationWithSampleEvent(),
      );
      return;
    }

    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        context.read<LocateMeBloc>().add(
          StartLocalizationEvent(capturedImagePath: image.path),
        );
      }
    } catch (e) {
      // Fallback to sample image
      if (mounted) {
        context.read<LocateMeBloc>().add(
          const StartLocalizationWithSampleEvent(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<LocateMeBloc, LocateMeState>(
      listener: (context, state) {
        if (state is LocateMeError) {
          CustomSnackBar.show(
            context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, state) {
        // If we have floor plan ready, show the floor plan page
        if (state is LocateMeReady) {
          return const LocateMeFloorPlanPage();
        }

        // Show loading state
        if (state is LocateMeLoading) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: CustomLoadingView(message: state.message),
          );
        }

        // Show camera view
        return _buildCameraView(context, theme);
      },
    );
  }

  Widget _buildCameraView(BuildContext context, ThemeData theme) {
    if (_isInitializing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(_controller!),

          // Header
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, theme),
                const Expanded(child: _CameraGuidance()),
              ],
            ),
          ),

          // Footer Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFooter(context, theme),
          ),

          // Sample Image Overlay
          if (_showSample) _buildSampleOverlay(context, theme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Locate Me',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(bottom: 50, top: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Point camera at floor and walls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Close button
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
              // Capture button
              GestureDetector(
                onTap: _captureAndLocalize,
                child: Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: theme.colorScheme.onPrimary,
                      size: 36,
                    ),
                  ),
                ),
              ),
              // Sample button
              Column(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showSample = !_showSample),
                    icon: Icon(
                      _showSample ? Icons.visibility : Icons.help_outline,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  Text(
                    'SAMPLE',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSampleOverlay(BuildContext context, ThemeData theme) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSample = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'IDEAL VIEW',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/mock_data/good_photo_sample.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.surface,
                          child: Icon(
                            Icons.image,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.2),
                            size: 80,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.black45,
                        child: const Text(
                          'Clear floor and walls visible',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'TAP ANYWHERE TO CLOSE',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
