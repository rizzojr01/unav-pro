import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class ThemePalette extends Equatable {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;

  const ThemePalette({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
  });

  factory ThemePalette.defaultLight() {
    return const ThemePalette(
      primary: Color(0xFFB8E600),
      secondary: Color(0xFF1E1E1E),
      background: Color(0xFFF8F9FA),
      surface: Color(0xFFFFFFFF),
      error: Color(0xFFFF5252),
    );
  }

  factory ThemePalette.defaultDark() {
    return const ThemePalette(
      primary: Color(0xFFB8E600),
      secondary: Color(0xFF1E1E1E),
      background: Color(0xFF121212),
      surface: Color(0xFF1E1E1E),
      error: Color(0xFFFF5252),
    );
  }

  ThemePalette copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? error,
  }) {
    return ThemePalette(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      error: error ?? this.error,
    );
  }

  Map<String, int> toJson() {
    return {
      'primary': primary.toARGB32(),
      'secondary': secondary.toARGB32(),
      'background': background.toARGB32(),
      'surface': surface.toARGB32(),
      'error': error.toARGB32(),
    };
  }

  factory ThemePalette.fromJson(Map<String, dynamic> json) {
    return ThemePalette(
      primary: Color(json['primary'] as int),
      secondary: Color(json['secondary'] as int),
      background: Color(json['background'] as int),
      surface: Color(json['surface'] as int),
      error: Color(json['error'] as int),
    );
  }

  @override
  List<Object?> get props => [primary, secondary, background, surface, error];
}
