import 'package:equatable/equatable.dart';

/// Base event class for all BLoC events
/// All events should extend this class for value equality
abstract class BaseEvent extends Equatable {
  const BaseEvent();

  @override
  List<Object?> get props => [];
}
