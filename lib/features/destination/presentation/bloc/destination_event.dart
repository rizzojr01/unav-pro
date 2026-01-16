import 'package:equatable/equatable.dart';

abstract class DestinationEvent extends Equatable {
  const DestinationEvent();

  @override
  List<Object?> get props => [];
}

class SearchDestinationsEvent extends DestinationEvent {
  final String query;

  const SearchDestinationsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class SelectDestinationEvent extends DestinationEvent {
  final String destinationId;

  const SelectDestinationEvent(this.destinationId);

  @override
  List<Object?> get props => [destinationId];
}

class RestoreDestinationsEvent extends DestinationEvent {
  const RestoreDestinationsEvent();
}
