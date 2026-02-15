import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/services/recent_destinations_service.dart';
import '../../domain/entities/destination_entity.dart';
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
    List<DestinationEntity> destinations;
    if (state is DestinationSearchSuccess) {
      destinations = (state as DestinationSearchSuccess).destinations;
    } else if (state is DestinationSelected) {
      destinations = (state as DestinationSelected).destinations ?? [];
    } else {
      return;
    }

    if (destinations.isEmpty) return;

    // Use List.from to ensure we have a List<DestinationEntity> at runtime,
    // avoiding covariance issues with orElse return type mismatch.
    final items = List<DestinationEntity>.from(destinations);
    final destination = items.firstWhere(
      (d) => d.id == event.destinationId,
      orElse: () => items.first,
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
    List<DestinationEntity>? existingDestinations;

    if (state is DestinationSelected) {
      existingDestinations = (state as DestinationSelected).destinations;
    } else if (state is DestinationSearchSuccess) {
      existingDestinations = (state as DestinationSearchSuccess).destinations;
    }

    if (existingDestinations != null && existingDestinations.isNotEmpty) {
      emit(DestinationSearchSuccess(existingDestinations));
      return;
    }

    // Refresh if no list exists
    emit(const DestinationSearching());
    final result = await searchDestinationsUseCase('');
    result.fold(
      (failure) => emit(DestinationError(failure.message)),
      (destinations) => emit(DestinationSearchSuccess(destinations)),
    );
  }
}
