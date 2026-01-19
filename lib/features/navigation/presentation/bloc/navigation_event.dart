import 'package:equatable/equatable.dart';
import '../../../destination/domain/entities/destination_entity.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNavigationEvent extends NavigationEvent {
  final DestinationEntity destination;
  final String? imagePath;

  const InitializeNavigationEvent(this.destination, {this.imagePath});

  @override
  List<Object?> get props => [destination, imagePath];
}
