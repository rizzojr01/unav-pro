import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:smart_sense/core/services/storage_service.dart';

// Events
abstract class ThemeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ThemeChanged extends ThemeEvent {
  final ThemeMode themeMode;
  ThemeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class LoadTheme extends ThemeEvent {}

// State
class ThemeState extends Equatable {
  final ThemeMode themeMode;
  const ThemeState(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

// Bloc
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final StorageService _storageService;
  static const String _themeKey = 'theme_mode';

  ThemeBloc(this._storageService) : super(const ThemeState(ThemeMode.system)) {
    on<ThemeChanged>(_onThemeChanged);
    on<LoadTheme>(_onLoadTheme);
  }

  Future<void> _onThemeChanged(
    ThemeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    await _storageService.setString(_themeKey, event.themeMode.toString());
    emit(ThemeState(event.themeMode));
  }

  void _onLoadTheme(LoadTheme event, Emitter<ThemeState> emit) {
    final savedTheme = _storageService.getString(_themeKey);
    if (savedTheme != null) {
      final mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedTheme,
        orElse: () => ThemeMode.system,
      );
      emit(ThemeState(mode));
    }
  }
}
