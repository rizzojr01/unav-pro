import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/ar_channel_contract.dart';
import '../bloc/ar_navigation_bloc.dart';
import '../bloc/ar_navigation_state.dart';
import './ar_guidance_banner.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ArPreviewFloatingWindow extends StatelessWidget {
  final VoidCallback onTap;

  const ArPreviewFloatingWindow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const _ArPreviewNativeView(),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: BlocBuilder<ArNavigationBloc, ArNavigationState>(
                builder: (context, state) {
                  if (state is ArNavigationTracking) {
                    return ArGuidanceBanner(
                      state: state.state,
                      remainingDistancePx: state.remainingDistancePx,
                      distanceToNextWaypointPx: state.distanceToNextWaypointPx,
                      message: state.guidanceMessage,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArPreviewNativeView extends StatefulWidget {
  const _ArPreviewNativeView();

  @override
  State<_ArPreviewNativeView> createState() => _ArPreviewNativeViewState();
}

class _ArPreviewNativeViewState extends State<_ArPreviewNativeView> {
  // Use a unique Key to force view recreation if needed, or maintain identity.
  // The error "trying to create an already created view" usually happens
  // when Flutter tries to rebuild the platform view with the same ID.
  static const _viewType = ArChannelContract.previewViewType;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const AndroidView(
        viewType: _viewType,
        creationParams: {},
        creationParamsCodec: StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // On iOS, using a UniqueKey can sometimes resolve re-creation conflicts
      // during hot reloads or rapid widget tree changes.
      return const UiKitView(
        key: ValueKey('ar_preview_view'),
        viewType: _viewType,
        creationParams: {},
        creationParamsCodec: StandardMessageCodec(),
      );
    } else {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white54),
      );
    }
  }
}
