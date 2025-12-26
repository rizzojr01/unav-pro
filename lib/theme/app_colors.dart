import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF5443C3);
  static const Color primaryLight = Color(0xFF8B7FF5);

  // Secondary Colors
  static const Color secondary = Color(0xFF00B894);
  static const Color secondaryDark = Color(0xFF009977);
  static const Color secondaryLight = Color(0xFF26D9A8);

  // Accent Colors
  static const Color accent = Color(0xFFFF7675);
  static const Color accentDark = Color(0xFFE85654);
  static const Color accentLight = Color(0xFFFF9F9E);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF2D3436);
  static const Color grey = Color(0xFF636E72);
  static const Color greyLight = Color(0xFFDFE6E9);
  static const Color greyDark = Color(0xFF2D3436);
  static const Color background = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surfaceDark = Color(0xFF16213E);

  // Status Colors
  static const Color success = Color(0xFF00B894);
  static const Color error = Color(0xFFFF7675);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color info = Color(0xFF74B9FF);

  // Gradient Colors (as Color lists for use in LinearGradient)
  static const List<Color> primaryGradient = [primary, primaryLight];
  static const List<Color> secondaryGradient = [secondary, secondaryLight];
  static const List<Color> accentGradient = [accent, accentLight];
  static const List<Color> successGradient = [success, secondaryLight];
  static const List<Color> infoGradient = [info, Color(0xFF9FD3FF)];
  static const List<Color> warningGradient = [warning, Color(0xFFFEDC90)];

  // Text Colors
  static const Color textPrimary = black;
  static const Color textSecondary = grey;
  static const Color textLight = greyLight;
}
