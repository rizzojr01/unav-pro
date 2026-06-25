import 'package:equatable/equatable.dart';
import 'package:smart_sense/features/navigation/domain/entities/route_entity.dart';
import '../../domain/entities/localized_pose.dart';
import '../../domain/entities/ar_pose.dart';

abstract class ArNavigationEvent extends Equatable {
  const ArNavigationEvent();

  @override
  List<Object?> get props => [];
}

class StartArNavigation extends ArNavigationEvent {
  final LocalizedPose referencePose;
  final double metersPerPixel;
  final RouteEntity route;
  final ArPose? originArPose;

  const StartArNavigation({
    required this.referencePose,
    required this.metersPerPixel,
    required this.route,
    this.originArPose,
  });

  @override
  List<Object?> get props => [
        referencePose,
        metersPerPixel,
        route,
        originArPose,
      ];
}

class StopArNavigation extends ArNavigationEvent {
  const StopArNavigation();
}

class UpdateArPose extends ArNavigationEvent {
  final ArPose pose;

  const UpdateArPose(this.pose);

  @override
  List<Object?> get props => [pose];
}

/// Internal event — emitted when the user's floorplan position reaches the
/// next pending floor transition. Pauses pose forwarding and surfaces the
/// awaiting-relocalize banner.
class FloorTransitionReached extends ArNavigationEvent {
  final int transitionIndex;

  const FloorTransitionReached(this.transitionIndex);

  @override
  List<Object?> get props => [transitionIndex];
}
