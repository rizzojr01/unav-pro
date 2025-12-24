import 'package:equatable/equatable.dart';
import '../../../destination/domain/entities/destination_entity.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNavigationEvent extends NavigationEvent {
  final DestinationEntity destination;

  const InitializeNavigationEvent(this.destination);

  @override
  List<Object?> get props => [destination];
}

class StartNavigationEvent extends NavigationEvent {
  const StartNavigationEvent();
}

class StopNavigationEvent extends NavigationEvent {
  const StopNavigationEvent();
}

class UpdateLocationEvent extends NavigationEvent {
  const UpdateLocationEvent();
}
