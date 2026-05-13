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

  const StartArNavigation({
    required this.referencePose,
    required this.metersPerPixel,
    required this.route,
  });

  @override
  List<Object?> get props => [
    referencePose,
    metersPerPixel,
    route,
  ];
}

class StopArNavigation extends ArNavigationEvent {}

class UpdateArPose extends ArNavigationEvent {
  final ArPose pose;

  const UpdateArPose(this.pose);

  @override
  List<Object?> get props => [pose];
}
