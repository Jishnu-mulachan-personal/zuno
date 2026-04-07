import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_theme_data.dart';

class ZunoTheme {
  // ─── Active Palette ───────────────────────────────────────────────────────
  static ZunoThemePalette _palette = ZunoThemePalette.hearth;

  static void applyPalette(ZunoThemePalette palette) {
    _palette = palette;
  }

  static ZunoThemePalette get currentPalette => _palette;

  // ─── Brand Colors (delegated to active palette) ───────────────────────────
  static Color get primary => _palette.primary;
  static Color get primaryContainer => _palette.primaryContainer;
  static Color get primaryFixed => _palette.primaryFixed;
  static Color get primaryFixedDim => _palette.primaryFixedDim;

  static Color get secondary => _palette.secondary;
  static Color get secondaryContainer => _palette.secondaryContainer;

  static Color get tertiary => _palette.tertiary;
  static Color get tertiaryFixed => _palette.tertiaryFixed;
  static Color get tertiaryFixedDim => _palette.tertiaryFixedDim;
  static Color get tertiaryContainer => _palette.tertiaryContainer;
  static Color get onTertiaryFixedVariant => _palette.onTertiaryFixedVariant;

  // ─── Surface Colors ───────────────────────────────────────────────────────
  static Color get surface => _palette.surface;
  static Color get surfaceBright => _palette.surfaceBright;
  static Color get surfaceDim => _palette.surfaceDim;
  static Color get surfaceContainerLowest => _palette.surfaceContainerLowest;
  static Color get surfaceContainerLow => _palette.surfaceContainerLow;
  static Color get surfaceContainer => _palette.surfaceContainer;
  static Color get surfaceContainerHigh => _palette.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _palette.surfaceContainerHighest;

  // ─── On-Surface ───────────────────────────────────────────────────────────
  static Color get onSurface => _palette.onSurface;
  static Color get onSurfaceVariant => _palette.onSurfaceVariant;
  static Color get onPrimary => _palette.onPrimary;
  static Color get onSecondary => _palette.onSecondary;
  static Color get onTertiary => _palette.onTertiary;

  // ─── Outline ──────────────────────────────────────────────────────────────
  static Color get outline => _palette.outline;
  static Color get outlineVariant => _palette.outlineVariant;

  // ─── Error ────────────────────────────────────────────────────────────────
  static Color get error => _palette.error;

  // ─── Gradients ───────────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  // ─── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData buildTheme() {
    final p = _palette;
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primaryFixed,
        onPrimaryContainer: p.brightness == Brightness.dark
            ? p.primaryFixed
            : const Color(0xFF551905),
        secondary: p.secondary,
        onSecondary: p.onSecondary,
        secondaryContainer: p.secondaryContainer,
        onSecondaryContainer: p.onSurfaceVariant,
        tertiary: p.tertiary,
        onTertiary: p.onTertiary,
        tertiaryContainer: p.tertiaryContainer,
        onTertiaryContainer: p.onTertiaryFixedVariant,
        error: p.error,
        onError: p.brightness == Brightness.dark ? p.onSurface : const Color(0xFFFFFFFF),
        errorContainer: p.brightness == Brightness.dark
            ? const Color(0xFF8B0000)
            : const Color(0xFFFFDAD6),
        onErrorContainer: p.brightness == Brightness.dark
            ? const Color(0xFFFFB4AB)
            : const Color(0xFF93000A),
        surface: p.surface,
        onSurface: p.onSurface,
        onSurfaceVariant: p.onSurfaceVariant,
        outline: p.outline,
        outlineVariant: p.outlineVariant,
        shadow: const Color(0xFF000000),
        scrim: const Color(0xFF000000),
        inverseSurface: p.onSurface,
        onInverseSurface: p.surface,
        inversePrimary: p.primaryFixedDim,
      ),
      scaffoldBackgroundColor: p.surface,
      textTheme: _buildTextTheme(p),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primaryContainer, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: p.onSurfaceVariant,
        ),
      ),
    );
    return base;
  }

  // Keep a `light` getter for backward compatibility
  static ThemeData get light => buildTheme();

  static TextTheme _buildTextTheme(ZunoThemePalette p) {
    return TextTheme(
      displayLarge: GoogleFonts.notoSerif(
        fontSize: 57, fontWeight: FontWeight.w600, color: p.onSurface,
        fontStyle: FontStyle.italic,
      ),
      displayMedium: GoogleFonts.notoSerif(
        fontSize: 45, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      displaySmall: GoogleFonts.notoSerif(
        fontSize: 36, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      headlineLarge: GoogleFonts.notoSerif(
        fontSize: 32, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      headlineMedium: GoogleFonts.notoSerif(
        fontSize: 28, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      headlineSmall: GoogleFonts.notoSerif(
        fontSize: 24, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: p.onSurface,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: p.onSurface,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: p.onSurface,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: p.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w700, color: p.onSurface,
        letterSpacing: 1.5,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: p.onSurface,
        letterSpacing: 1.5,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11, fontWeight: FontWeight.w600, color: p.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }
}
