import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_sense/features/destination/domain/entities/destination_entity.dart';
import 'package:smart_sense/shared/widgets/custom_error_view.dart';
import 'package:smart_sense/shared/widgets/custom_loading_view.dart';
import 'package:smart_sense/shared/widgets/loading_overlay.dart';
import 'package:smart_sense/shared/widgets/step_indicator.dart';

import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/location_input_view.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';

import '../widgets/photo_preview_widget.dart';

class CameraPage extends StatefulWidget {
  final DestinationEntity? destination;
  final Map<String, dynamic>? manualCoordinates;

  const CameraPage({super.key, this.destination, this.manualCoordinates});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<CameraBloc>().add(const InitializeCameraEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      return const CustomLoadingView(message: 'Initializing camera...');
    } else if (state is CameraReady) {
      return _CameraReadyView(
        tabController: _tabController,
        destination: widget.destination,
      );
    } else if (state is CameraPhotoCaptured) {
      return PhotoPreviewWidget(
        imagePath: state.photo.filePath,
        onRetake: () {
          context.read<CameraBloc>().add(const InitializeCameraEvent());
        },
        onContinue: () {
          context.pushReplacement(
            '/navigation',
            extra: {
              'destination': widget.destination,
              'imagePath': state.photo.filePath,
              'manualCoordinates': widget.manualCoordinates,
            },
          );
        },
      );
    } else if (state is CameraError) {
      return CustomErrorView(
        message: state.message,
        onRetry: () =>
            context.read<CameraBloc>().add(const InitializeCameraEvent()),
      );
    } else if (state is CameraCapturing) {
      return _CameraReadyView(
        tabController: _tabController,
        destination: widget.destination,
      );
    }
    return _CameraReadyView(
      tabController: _tabController,
      destination: widget.destination,
    );
  }
}

class _CameraReadyView extends StatelessWidget {
  final TabController tabController;
  final DestinationEntity? destination;

  const _CameraReadyView({required this.tabController, this.destination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header with tabs
        Container(
          color: theme.colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                StepIndicator(
                  currentStep: 2,
                  title: 'Find me..',
                  onBack: () => context.pop(),
                ),
                TabBar(
                  controller: tabController,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(icon: Icon(Icons.camera_alt_rounded), text: 'Camera'),
                    Tab(icon: Icon(Icons.map_rounded), text: 'Floor Plan'),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Tab content using shared widget
        Expanded(
          child: LocationInputView(
            tabController: tabController,
            floorPlanConfirmText: 'Start Navigation',
            onImageCaptured: (path) {
              context.read<CameraBloc>().add(CapturePhotoEvent(filePath: path));
            },
            onLocationSelected: (x, y) {
              context.pushReplacement(
                '/navigation',
                extra: {
                  'destination': destination,
                  'manualCoordinates': {
                    'x': x,
                    'y': y,
                    'ang': 0.0,
                    'enabled': true,
                  },
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
