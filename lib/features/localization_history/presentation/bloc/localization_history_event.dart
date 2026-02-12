import 'package:equatable/equatable.dart';

abstract class LocalizationHistoryEvent extends Equatable {
  const LocalizationHistoryEvent();

  @override
  List<Object?> get props => [];
}

class FetchLocalizationHistoryEvent extends LocalizationHistoryEvent {
  final String userIdentifier;
  final String identifierType;
  final int limit;

  const FetchLocalizationHistoryEvent({
    required this.userIdentifier,
    required this.identifierType,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [userIdentifier, identifierType, limit];
}
