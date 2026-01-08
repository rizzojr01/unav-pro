import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/custom_snackbar.dart';
import 'package:smart_sense/shared/widgets/loading_overlay.dart';
import 'package:smart_sense/shared/widgets/step_indicator.dart';
import 'package:smart_sense/features/destination/domain/entities/destination_entity.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';

class CameraPage extends StatefulWidget {
  final DestinationEntity? destination;

  const CameraPage({super.key, this.destination});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  @override
  void initState() {
    super.initState();
    context.read<CameraBloc>().add(const InitializeCameraEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraError) {
            CustomSnackBar.show(
              context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (context, state) {
          return LoadingOverlay(
            isLoading: state is CameraCapturing,
            message: 'Capturing photo...',
            child: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CameraState state) {
    if (state is CameraInitial) {
      return const _InitializingView();
    } else if (state is CameraReady) {
      return const _CameraReadyView();
    } else if (state is CameraPhotoCaptured) {
      return _PhotoPreviewView(state: state, destination: widget.destination);
    } else if (state is CameraError) {
      return _ErrorView(message: state.message);
    } else if (state is CameraCapturing) {
      return const _CameraReadyView();
    }
    return const _CameraReadyView();
  }
}

class _InitializingView extends StatelessWidget {
  const _InitializingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraReadyView extends StatefulWidget {
  const _CameraReadyView();

  @override
  State<_CameraReadyView> createState() => _CameraReadyViewState();
}

class _CameraReadyViewState extends State<_CameraReadyView> {
  CameraController? _controller;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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

  bool _showSample = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isInitializing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Camera Preview
          CameraPreview(_controller!),

          // 2. Header and Guidance Overlay
          Column(
            children: [
              StepIndicator(
                currentStep: 2,
                title: 'Find me..',
                onBack: () => context.pop(),
              ),
              const Expanded(child: _HorizontalGuidance()),
            ],
          ),

          // 4. Footer Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
                    'Keep floor and walls in view',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.read<CameraBloc>().add(
                            const CapturePhotoEvent(),
                          );
                        },
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
                              Icons.camera_alt,
                              color: theme.colorScheme.onPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () =>
                                setState(() => _showSample = !_showSample),
                            icon: Icon(
                              _showSample
                                  ? Icons.visibility
                                  : Icons.help_outline,
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
            ),
          ),

          // Sample Image Overlay
          if (_showSample)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showSample = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
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
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: theme.colorScheme.surface,
                                      child: Icon(
                                        Icons.image,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
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
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'TAP ANYWHERE TO CLOSE',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HorizontalGuidance extends StatelessWidget {
  const _HorizontalGuidance();

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

class _PhotoPreviewView extends StatelessWidget {
  final CameraPhotoCaptured state;
  final DestinationEntity? destination;

  const _PhotoPreviewView({required this.state, this.destination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with placeholder fallback
          File(state.photo.filePath).existsSync()
              ? Image.file(File(state.photo.filePath), fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 80,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PREVIEW NOT AVAILABLE',
                          style: TextStyle(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

          // Dark Gradient Overlay for readability
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black45,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0.0, 0.2, 0.6, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),

                const Spacer(),

                // Footer Controls
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Is this photo clear?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ensure the image isn\'t blurry for best results.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 32),

                      // Primary Action
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<CameraBloc>().add(
                              const UploadPhotoEvent(),
                            );
                            // Navigate to navigation page directly with the destination
                            if (destination != null) {
                              context.push('/navigation', extra: destination);
                            } else {
                              context.push('/location-detection');
                            }
                          },
                          child: const Text(
                            'Confirm & Analyze',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Secondary Action
                      TextButton(
                        onPressed: () => context.read<CameraBloc>().add(
                          const InitializeCameraEvent(),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Retake Photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.read<CameraBloc>().add(const InitializeCameraEvent());
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
