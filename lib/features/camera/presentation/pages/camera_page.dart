import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../../../theme/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

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
    return Scaffold(
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraPhotoUploaded) {
            CustomSnackBar.show(
              context,
              message: 'Photo uploaded successfully!',
              type: SnackBarType.success,
            );
            Navigator.pushNamed(context, '/location-detection');
          } else if (state is CameraError) {
            CustomSnackBar.show(
              context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (context, state) {
          return LoadingOverlay(
            isLoading: state is CameraCapturing || state is CameraUploading,
            message: state is CameraCapturing
                ? 'Capturing photo...'
                : 'Uploading photo...',
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
      return _PhotoPreviewView(state: state);
    } else if (state is CameraError) {
      return _ErrorView(message: state.message);
    }
    return const SizedBox.shrink();
  }
}

class _InitializingView extends StatelessWidget {
  const _InitializingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.primaryGradient,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.white),
            SizedBox(height: 24),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: AppColors.white,
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Capture Photo',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.white),
                    )
                  : _controller == null || !_controller!.value.isInitialized
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 80,
                            color: AppColors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Camera not available',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CameraPreview(_controller!),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: CustomButton(
                text: 'Capture Photo',
                onPressed:
                    _controller != null && _controller!.value.isInitialized
                    ? () {
                        context.read<CameraBloc>().add(
                          const CapturePhotoEvent(),
                        );
                      }
                    : null,
                backgroundColor: AppColors.white,
                textColor: AppColors.primary,
                width: double.infinity,
                icon: Icons.camera,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreviewView extends StatelessWidget {
  final CameraPhotoCaptured state;

  const _PhotoPreviewView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Photo Preview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: CustomCard(
                      hasShadow: true,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: File(state.photo.filePath).existsSync()
                            ? Image.file(
                                File(state.photo.filePath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Photo captured successfully!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Retake',
                    onPressed: () {
                      context.read<CameraBloc>().add(
                        const InitializeCameraEvent(),
                      );
                    },
                    isOutlined: true,
                    icon: Icons.refresh,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Continue',
                    onPressed: () {
                      context.read<CameraBloc>().add(const UploadPhotoEvent());
                    },
                    icon: Icons.arrow_forward,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Try Again',
              onPressed: () {
                context.read<CameraBloc>().add(const InitializeCameraEvent());
              },
              width: double.infinity,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }
}
