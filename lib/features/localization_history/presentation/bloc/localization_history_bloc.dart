import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_user_localization_history_usecase.dart';
import 'localization_history_event.dart';
import 'localization_history_state.dart';

class LocalizationHistoryBloc
    extends Bloc<LocalizationHistoryEvent, LocalizationHistoryState> {
  final GetUserLocalizationHistoryUseCase getUserLocalizationHistoryUseCase;

  LocalizationHistoryBloc({
    required this.getUserLocalizationHistoryUseCase,
  }) : super(const LocalizationHistoryInitial()) {
    on<FetchLocalizationHistoryEvent>(_onFetchLocalizationHistory);
  }

  Future<void> _onFetchLocalizationHistory(
    FetchLocalizationHistoryEvent event,
    Emitter<LocalizationHistoryState> emit,
  ) async {
    emit(const LocalizationHistoryLoading());

    final result = await getUserLocalizationHistoryUseCase(
      GetUserHistoryParams(
        userIdentifier: event.userIdentifier,
        identifierType: event.identifierType,
        limit: event.limit,
      ),
    );

    result.fold(
      (failure) => emit(LocalizationHistoryError(failure.message)),
      (history) => emit(LocalizationHistorySuccess(history)),
    );
  }
}
