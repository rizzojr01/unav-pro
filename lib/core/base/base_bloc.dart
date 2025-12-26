import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/core/base/base_state.dart';
import 'package:smart_sense/core/base/base_event.dart';

/// Base BLoC class that extends Bloc from flutter_bloc
/// All feature BLoCs should extend this class
abstract class BaseBloc<E extends BaseEvent, S extends BaseState>
    extends Bloc<E, S> {
  BaseBloc(super.initialState);

  /// Handle errors and convert them to an error state
  /// Override in subclasses to return specific error states
  S handleError(Object error, StackTrace stackTrace) {
    // This is a default implementation that subclasses must override
    throw UnimplementedError(
      'handleError must be overridden in $runtimeType to return a specific error state',
    );
  }
}
