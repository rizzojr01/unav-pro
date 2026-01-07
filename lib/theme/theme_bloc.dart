import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:smart_sense/core/services/storage_service.dart';
import 'theme_palette.dart';

// Events
abstract class ThemeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ThemeModeChanged extends ThemeEvent {
  final ThemeMode themeMode;
  ThemeModeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class ThemePaletteChanged extends ThemeEvent {
  final ThemePalette palette;
  ThemePaletteChanged(this.palette);

  @override
  List<Object?> get props => [palette];
}

class LoadTheme extends ThemeEvent {}

// State
class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final ThemePalette palette;

  const ThemeState({required this.themeMode, required this.palette});

  @override
  List<Object?> get props => [themeMode, palette];

  ThemeState copyWith({ThemeMode? themeMode, ThemePalette? palette}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
    );
  }
}

// Bloc
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final StorageService _storageService;
  static const String _themeModeKey = 'theme_mode';
  static const String _paletteKey = 'theme_palette';

  ThemeBloc(this._storageService)
    : super(
        ThemeState(
          themeMode: ThemeMode.system,
          palette: ThemePalette.defaultLight(),
        ),
      ) {
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<ThemePaletteChanged>(_onThemePaletteChanged);
    on<LoadTheme>(_onLoadTheme);
  }

  Future<void> _onThemeModeChanged(
    ThemeModeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    await _storageService.setString(_themeModeKey, event.themeMode.toString());
    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onThemePaletteChanged(
    ThemePaletteChanged event,
    Emitter<ThemeState> emit,
  ) async {
    await _storageService.setString(
      _paletteKey,
      jsonEncode(event.palette.toJson()),
    );
    emit(state.copyWith(palette: event.palette));
  }

  void _onLoadTheme(LoadTheme event, Emitter<ThemeState> emit) {
    final savedMode = _storageService.getString(_themeModeKey);
    final savedPaletteJson = _storageService.getString(_paletteKey);

    ThemeMode mode = ThemeMode.system;
    if (savedMode != null) {
      mode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => ThemeMode.system,
      );
    }

    ThemePalette palette = mode == ThemeMode.dark
        ? ThemePalette.defaultDark()
        : ThemePalette.defaultLight();

    if (savedPaletteJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(savedPaletteJson);
        palette = ThemePalette.fromJson(json);
      } catch (_) {
        // Fallback to defaults if parsing fails
      }
    }

    emit(ThemeState(themeMode: mode, palette: palette));
  }
}
