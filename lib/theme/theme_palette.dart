import 'package:equatable/equatable.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

/// Theme palette using FlexColorScheme
class ThemePalette extends Equatable {
  final FlexScheme scheme;

  const ThemePalette({required this.scheme});

  factory ThemePalette.defaultLight() {
    return const ThemePalette(scheme: FlexScheme.indigo);
  }

  factory ThemePalette.defaultDark() {
    return const ThemePalette(scheme: FlexScheme.indigo);
  }

  ThemePalette copyWith({FlexScheme? scheme}) {
    return ThemePalette(scheme: scheme ?? this.scheme);
  }

  Map<String, dynamic> toJson() {
    return {'scheme': scheme.index};
  }

  factory ThemePalette.fromJson(Map<String, dynamic> json) {
    final schemeIndex = json['scheme'] as int;
    // Ensure the index is valid
    if (schemeIndex >= 0 && schemeIndex < FlexScheme.values.length) {
      return ThemePalette(scheme: FlexScheme.values[schemeIndex]);
    }
    // Fallback to default if invalid
    return ThemePalette.defaultLight();
  }

  @override
  List<Object?> get props => [scheme];
}
