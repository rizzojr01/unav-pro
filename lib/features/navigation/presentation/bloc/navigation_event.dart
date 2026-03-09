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
  final Map<String, dynamic>? userPickedCoordinates;
  final String? pickedFloor;
  final double? heading;

  const InitializeNavigationEvent(
    this.destination, {
    this.imagePath,
    this.userPickedCoordinates,
    this.pickedFloor,
    this.heading,
  });

  @override
  List<Object?> get props => [
    destination,
    imagePath,
    userPickedCoordinates,
    pickedFloor,
    heading,
  ];
}
