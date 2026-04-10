import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../../../shared/widgets/map_view.dart';
import '../../../../shared/widgets/offset_settings_modal.dart';
import '../../../destination/domain/entities/destination_entity.dart';
import '../bloc/locate_me_bloc.dart';
import '../bloc/locate_me_event.dart';
import '../bloc/locate_me_state.dart';
import '../widgets/destination_bottom_sheet.dart';

class LocateMeFloorPlanPage extends StatefulWidget {
  const LocateMeFloorPlanPage({super.key});

  @override
  State<LocateMeFloorPlanPage> createState() => _LocateMeFloorPlanPageState();
}

class _LocateMeFloorPlanPageState extends State<LocateMeFloorPlanPage> {
  void _showDestinationBottomSheet(
    BuildContext context,
    DestinationEntity destination,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DestinationBottomSheet(
        destination: destination,
        onNavigate: () {
          if (modalContext.mounted) {
            Navigator.pop(modalContext);
          }
          if (mounted) {
            final locateState = context.read<LocateMeBloc>().state;
            if (locateState is LocateMeReady) {
              context.push(
                '/navigation',
                extra: {
                  'destination': destination,
                  'manualCoordinates': {
                    'x': locateState.userPosition.x,
                    'y': locateState.userPosition.y,
                    'ang': locateState.userPosition.angle,
                    'enabled': true,
                  },
                  'pickedFloor': locateState.floor,
                  'heading': locateState.heading,
                },
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<LocateMeBloc, LocateMeState>(
      builder: (context, state) {
        if (state is! LocateMeReady) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context, theme),
              Expanded(
                child: Stack(
                  children: [
                    MapView(
                      userLocation: state.userPosition,
                      floorPlanBase64: state.floorPlan.base64Image,
                      destinations: state.destinations,
                      onDestinationTap: (destination) =>
                          _showDestinationBottomSheet(context, destination),
                      onRetry: () {
                        context.read<LocateMeBloc>().add(
                          const ResetLocateMeEvent(),
                        );
                      },
                      onRelocalize: () {
                        if (mounted) {
                          context.read<LocateMeBloc>().add(
                            const ResetLocateMeEvent(),
                          );
                          context.pop();
                        }
                      },
                      autoCenterOnUser: true,
                      captureHeading: state.heading,
                    ),
                    // Offset Settings Button
                    Positioned(
                      left: 16,
                      bottom: 80, // Positioned above the info button in MapView
                      child: FloatingActionButton.small(
                        onPressed: () => showOffsetSettingsModal(context),
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.primary,
                        heroTag: 'offset_settings_fab_locate_me',
                        child: const Icon(Icons.settings_input_component),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (mounted) {
                context.read<LocateMeBloc>().add(const ResetLocateMeEvent());
                context.pop();
              }
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                FirebaseCrashlytics.instance.log('Manual crash triggered by user');
                FirebaseCrashlytics.instance.crash();
              },
              child: const Text(
                'Your Location',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              if (mounted) {
                context.read<LocateMeBloc>().add(const ResetLocateMeEvent());
              }
            },
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
