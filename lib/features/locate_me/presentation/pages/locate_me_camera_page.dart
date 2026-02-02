import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/custom_loading_view.dart';
import '../../../../shared/widgets/custom_snackbar.dart' as snackbar;
import '../../../../shared/widgets/location_input_view.dart';
import '../bloc/locate_me_bloc.dart';
import '../bloc/locate_me_event.dart';
import '../bloc/locate_me_state.dart';

import '../../../camera/presentation/widgets/photo_preview_widget.dart';

class LocateMeCameraPage extends StatefulWidget {
  const LocateMeCameraPage({super.key});

  @override
  State<LocateMeCameraPage> createState() => _LocateMeCameraPageState();
}

class _LocateMeCameraPageState extends State<LocateMeCameraPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<LocateMeBloc, LocateMeState>(
      listener: (context, state) {
        if (state is LocateMeReady) {
          context.push(
            '/locate-me/floor-plan',
            extra: context.read<LocateMeBloc>(),
          );
        } else if (state is LocateMeError) {
          snackbar.CustomSnackBar.show(
            context,
            message: state.message,
            type: snackbar.SnackBarType.error,
          );
        }
      },
      child: BlocBuilder<LocateMeBloc, LocateMeState>(
        builder: (context, state) {
          if (state is LocateMePhotoCaptured) {
            return PhotoPreviewWidget(
              imagePath: state.imagePath,
              onRetake: () {
                context.read<LocateMeBloc>().add(const ResetLocateMeEvent());
              },
              onContinue: () {
                context.read<LocateMeBloc>().add(
                  StartLocalizationEvent(capturedImagePath: state.imagePath),
                );
              },
            );
          }

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Locate Me',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                tabs: const [
                  Tab(icon: Icon(Icons.camera_alt_rounded), text: 'Camera'),
                  Tab(icon: Icon(Icons.map_rounded), text: 'Floor Plan'),
                ],
              ),
            ),
            body: state is LocateMeLoading
                ? CustomLoadingView(message: state.message)
                : LocationInputView(
                    tabController: _tabController,
                    onImageCaptured: (path) {
                      context.read<LocateMeBloc>().add(
                        LocateMeCapturePhotoEvent(capturedImagePath: path),
                      );
                    },
                    onLocationSelected: (x, y) {
                      context.read<LocateMeBloc>().add(
                        StartLocalizationWithCoordinatesEvent(x: x, y: y),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
