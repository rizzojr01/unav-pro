import 'package:equatable/equatable.dart';
import '../../domain/entities/localization_history_entity.dart';

abstract class LocalizationHistoryState extends Equatable {
  const LocalizationHistoryState();

  @override
  List<Object?> get props => [];
}

class LocalizationHistoryInitial extends LocalizationHistoryState {
  const LocalizationHistoryInitial();
}

class LocalizationHistoryLoading extends LocalizationHistoryState {
  const LocalizationHistoryLoading();
}

class LocalizationHistorySuccess extends LocalizationHistoryState {
  final List<LocalizationHistoryEntity> history;

  const LocalizationHistorySuccess(this.history);

  @override
  List<Object?> get props => [history];
}

class LocalizationHistoryError extends LocalizationHistoryState {
  final String message;

  const LocalizationHistoryError(this.message);

  @override
  List<Object?> get props => [message];
}
