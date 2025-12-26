import 'package:equatable/equatable.dart';

/// Base state class for all BLoC states
/// All states should extend this class for value equality
abstract class BaseState extends Equatable {
  const BaseState();

  @override
  List<Object?> get props => [];
}
