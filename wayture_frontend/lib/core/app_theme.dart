import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// AppTheme — Wayture red/white theme
/// ──────────────────────────────────────────────────────────────────────────
/// Central palette, typography, radii and [ThemeData] for the whole app.
/// Screens and widgets should read colors from [AppColors] (or the
/// [Theme.of] chain) rather than hard-coding hex values.
/// ──────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Primary palette ──
  static const Color primaryRed    = Color(0xFFE53935);
  static const Color darkRed       = Color(0xFFC62828);
  static const Color white         = Color(0xFFFFFFFF);
  static const Color lightGrey     = Color(0xFFF5F5F5);
  static const Color darkGrey      = Color(0xFF424242);
  static const Color textBlack     = Color(0xFF212121);
  static const Color mutedText     = Color(0xFF9E9E9E);

  // ── Semantic colors ──
  static const Color successGreen  = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF6F00);
  static const Color infoBlue      = Color(0xFF1E88E5);
  static const Color errorRed      = Color(0xFFC62828);

  // ── Traffic congestion colors ──
  static const Color trafficGreen  = Color(0xFF43A047); // free flow
  static const Color trafficYellow = Color(0xFFFDD835); // moderate
  static const Color trafficRed    = Color(0xFFE53935); // heavy

  // ── Legacy aliases kept so existing screens compile unchanged ──
  /// Old code references `AppColors.primary` — map it onto primaryRed.
  static const Color primary       = primaryRed;
  /// Old code references `AppColors.primaryDark` — map it onto darkRed.
  static const Color primaryDark   = darkRed;
  /// Old code references `AppColors.accent` — map it onto warningOrange.
  static const Color accent        = warningOrange;
}

/// Shared radii — keep these in sync with what dialogs/buttons use.
class AppRadii {
  AppRadii._();

  static const double card   = 16.0;
  static const double button = 12.0;
  static const double dialog = 20.0;
  static const double chip   = 8.0;
}

/// Shared text styles (Poppins) — the app's typography scale.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading({
    double fontSize = 18,
    Color color = AppColors.textBlack,
  }) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle body({
    double fontSize = 14,
    Color color = AppColors.textBlack,
  }) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle button({
    double fontSize = 15,
    Color color = AppColors.white,
  }) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        secondary: AppColors.darkRed,
        error: AppColors.errorRed,
        surface: AppColors.white,
      ),
      textTheme: base.apply(
        bodyColor: AppColors.textBlack,
        displayColor: AppColors.textBlack,
      ),

      // ── AppBar theme ──
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.white,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),

      // ── Bottom navigation theme ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primaryRed,
        unselectedItemColor: AppColors.mutedText,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),

      // ── Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: AppColors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(color: AppColors.mutedText),
      ),

      // ── SnackBars ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }

  /// A pared-down dark variant so screens that read `AppTheme.darkTheme`
  /// still compile. Wayture's brand is red-on-white, so the dark theme
  /// keeps the same accent but swaps the background surfaces.
  static ThemeData get darkTheme {
    final base = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D1A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        brightness: Brightness.dark,
        surface: const Color(0xFF0D0D1A),
      ),
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.white,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    );
  }
}
