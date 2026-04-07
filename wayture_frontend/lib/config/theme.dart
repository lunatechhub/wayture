import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wayture color palette
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00897B);
  static const Color primaryDark = Color(0xFF00695C);
  static const Color accent = Color(0xFFFF6F00);
  static const Color trafficGreen = Color(0xFF4CAF50);
  static const Color trafficYellow = Color(0xFFFFC107);
  static const Color trafficRed = Color(0xFFF44336);
}

/// App themes — light (sunset glassmorphism) and dark (AMOLED black).
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.poppinsTextTheme(),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        brightness: Brightness.dark,
        surface: const Color(0xFF0D0D1A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D0D1A),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
