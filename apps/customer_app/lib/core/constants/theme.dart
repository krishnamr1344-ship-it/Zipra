import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand — Warm Orange
  static const Color primary = Color(0xFFE65100);
  static const Color primaryLight = Color(0xFFFF8F00);
  static const Color primaryDark = Color(0xFFBF360C);
  static const Color primaryContainer = Color(0xFFFFF3E0);
  static const Color onPrimary = Colors.white;

  // Secondary — Blue Grey
  static const Color secondary = Color(0xFF37474F);
  static const Color secondaryLight = Color(0xFF62727B);
  static const Color secondaryContainer = Color(0xFFCFD8DC);
  static const Color onSecondary = Colors.white;

  // Surface & Background
  static const Color background = Color(0xFFFFF8F3);
  static const Color surface = Colors.white;
  static const Color surfaceDim = Color(0xFFF5F5F5);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFFF8F00);
  static const Color warningLight = Color(0xFFFFF8E1);

  // Misc
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);
  static const Color chipBg = Color(0xFFF5F5F5);

  // Category card backgrounds
  static const List<Color> categoryColors = [
    Color(0xFFFFF3E0), // Orange
    Color(0xFFE8F5E9), // Green
    Color(0xFFE3F2FD), // Blue
    Color(0xFFFCE4EC), // Pink
    Color(0xFFF3E5F5), // Purple
    Color(0xFFFFF8E1), // Yellow
    Color(0xFFE0F7FA), // Cyan
    Color(0xFFEFEBE9), // Brown
  ];

  // Gradient helpers
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFE65100), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
