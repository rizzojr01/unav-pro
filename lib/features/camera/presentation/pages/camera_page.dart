import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      appBar: AppBar(title: const Text('Capture Photo')),
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraPhotoUploaded) {
            // Navigate to destination selection
            Navigator.pushNamed(context, '/destination');
          } else if (state is CameraError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is CameraInitial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CameraReady) {
            return _buildCameraView(context);
          } else if (state is CameraCapturing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Capturing photo...'),
                ],
              ),
            );
          } else if (state is CameraPhotoCaptured) {
            return _buildPhotoPreview(context, state);
          } else if (state is CameraUploading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading photo...'),
                ],
              ),
            );
          } else if (state is CameraError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CameraBloc>().add(
                        const InitializeCameraEvent(),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCameraView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 100, color: Colors.blue),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.read<CameraBloc>().add(const CapturePhotoEvent());
            },
            icon: const Icon(Icons.camera),
            label: const Text('Capture Photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(BuildContext context, CameraPhotoCaptured state) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const SizedBox(height: 16),
                const Text('Photo captured successfully!'),
                const SizedBox(height: 8),
                Text(
                  'Path: ${state.photo.filePath}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<CameraBloc>().add(
                      const InitializeCameraEvent(),
                    );
                  },
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<CameraBloc>().add(const UploadPhotoEvent());
                  },
                  child: const Text('Upload & Continue'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
