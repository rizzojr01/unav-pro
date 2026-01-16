import '../../../../core/base/base_state.dart';
import '../../domain/entities/destination_entity.dart';

abstract class DestinationState extends BaseState {
  const DestinationState();
}

class DestinationInitial extends DestinationState {
  const DestinationInitial();
}

class DestinationSearching extends DestinationState {
  const DestinationSearching();
}

class DestinationSearchSuccess extends DestinationState {
  final List<DestinationEntity> destinations;

  const DestinationSearchSuccess(this.destinations);

  @override
  List<Object?> get props => [destinations];
}

class DestinationSelected extends DestinationState {
  final DestinationEntity destination;
  final List<DestinationEntity>? destinations;

  const DestinationSelected(this.destination, {this.destinations});

  @override
  List<Object?> get props => [destination, destinations];
}

class DestinationError extends DestinationState {
  final String message;

  const DestinationError(this.message);

  @override
  List<Object?> get props => [message];
}
