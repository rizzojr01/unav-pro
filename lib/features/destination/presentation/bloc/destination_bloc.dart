import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/services/recent_destinations_service.dart';
import '../../domain/usecases/search_destinations_usecase.dart';
import '../../domain/usecases/select_destination_usecase.dart';
import 'destination_event.dart';
import 'destination_state.dart';

class DestinationBloc extends Bloc<DestinationEvent, DestinationState> {
  final SearchDestinationsUseCase searchDestinationsUseCase;
  final SelectDestinationUseCase selectDestinationUseCase;
  final RecentDestinationsService recentDestinationsService;

  DestinationBloc({
    required this.searchDestinationsUseCase,
    required this.selectDestinationUseCase,
    required this.recentDestinationsService,
  }) : super(const DestinationInitial()) {
    on<SearchDestinationsEvent>(_onSearchDestinations);
    on<SelectDestinationEvent>(_onSelectDestination);
    on<RestoreDestinationsEvent>(_onRestoreDestinations);
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

    final currentState = state as DestinationSearchSuccess;
    final destinations = currentState.destinations;
    final destination = destinations.firstWhere(
      (d) => d.id == event.destinationId,
      orElse: () => throw StateError('Destination not found'),
    );

    // Save to recent destinations
    await recentDestinationsService.addRecentDestination(destination);

    // Emit selected state but preserve the destinations list
    emit(DestinationSelected(destination, destinations: destinations));
  }

  Future<void> _onRestoreDestinations(
    RestoreDestinationsEvent event,
    Emitter<DestinationState> emit,
  ) async {
    // If current state is DestinationSelected, restore the destinations list
    if (state is DestinationSelected) {
      final selectedState = state as DestinationSelected;
      if (selectedState.destinations != null &&
          selectedState.destinations!.isNotEmpty) {
        emit(DestinationSearchSuccess(selectedState.destinations!));
        return;
      }
    }

    // If already in success state with destinations, do nothing
    if (state is DestinationSearchSuccess) {
      final successState = state as DestinationSearchSuccess;
      if (successState.destinations.isNotEmpty) {
        return;
      }
    }

    // Otherwise, fetch destinations from cache/API
    emit(const DestinationSearching());
    final result = await searchDestinationsUseCase('');
    result.fold(
      (failure) => emit(DestinationError(failure.message)),
      (destinations) => emit(DestinationSearchSuccess(destinations)),
    );
  }
}
