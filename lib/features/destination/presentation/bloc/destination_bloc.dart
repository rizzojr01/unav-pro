import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/search_destinations_usecase.dart';
import '../../domain/usecases/select_destination_usecase.dart';
import 'destination_event.dart';
import 'destination_state.dart';

class DestinationBloc extends Bloc<DestinationEvent, DestinationState> {
  final SearchDestinationsUseCase searchDestinationsUseCase;
  final SelectDestinationUseCase selectDestinationUseCase;

  DestinationBloc({
    required this.searchDestinationsUseCase,
    required this.selectDestinationUseCase,
  }) : super(const DestinationInitial()) {
    on<SearchDestinationsEvent>(_onSearchDestinations);
    on<SelectDestinationEvent>(_onSelectDestination);
  }

  Future<void> _onSearchDestinations(
    SearchDestinationsEvent event,
    Emitter<DestinationState> emit,
  ) async {
    emit(const DestinationSearching());

    final result = await searchDestinationsUseCase(event.query);

    result.fold(
      (failure) => emit(DestinationError(failure.message)),
      (destinations) => emit(DestinationSearchSuccess(destinations)),
    );
  }

  Future<void> _onSelectDestination(
    SelectDestinationEvent event,
    Emitter<DestinationState> emit,
  ) async {
    if (state is! DestinationSearchSuccess) return;

    final destinations = (state as DestinationSearchSuccess).destinations;
    final destination = destinations.firstWhere(
      (d) => d.id == event.destinationId,
      orElse: () => throw StateError('Destination not found'),
    );

    // Directly emit the selected destination since we already have it
    emit(DestinationSelected(destination));
  }
}
