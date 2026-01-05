import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Darker Lime Green - Tech Theme)
  static const Color primary = Color(0xFFB8E600); // Darker Lime Green
  static const Color primaryDark = Color(0xFF82A300);
  static const Color primaryLight = Color(0xFFD4FF33);

  // Secondary Colors (Dark Slate for Premium Feel)
  static const Color secondary = Color(0xFF1E1E1E); // Card Background Dark
  static const Color secondaryDark = Color(0xFF121212); // App Background Dark
  static const Color secondaryLight = Color(0xFF2C2C2C);

  // Accent Colors
  static const Color accent = Color(0xFFB8E600);
  static const Color accentDark = Color(0xFF82A300);
  static const Color accentLight = Color(0xFFFFFFFF);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF121212);

  static const Color grey = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFE0E0E0);
  static const Color greyDark = Color(0xFF424242);

  // Background and Surfaces
  static const Color background = Color(0xFFF8F9FA); // Clean Light
  static const Color backgroundDark = Color(0xFF121212); // Deep Dark
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Status Colors
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF448AFF);

  // UI Tokens
  static const Color textPrimary = Color(0xFF1A1A1A); // Almost Black
  static const Color textSecondary = greyDark;
  static const Color textLight = white;
  static const Color textOnPrimary = Color(
    0xFF1A1A1A,
  ); // Dark text on Lime is highly readable
}
