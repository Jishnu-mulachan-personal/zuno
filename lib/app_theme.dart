import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZunoTheme {
  // ─── Brand Colors (Digital Hearth) ───────────────────────────────────────
  static const primary = Color(0xFF944931);
  static const primaryContainer = Color(0xFFD67D61);
  static const primaryFixed = Color(0xFFFFDBD0);
  static const primaryFixedDim = Color(0xFFFFB59E);

  static const secondary = Color(0xFF7D5548);
  static const secondaryContainer = Color(0xFFFEC8B8);

  static const tertiary = Color(0xFF006A6A);
  static const tertiaryFixed = Color(0xFF93F2F2);
  static const tertiaryFixedDim = Color(0xFF76D6D5);
  static const tertiaryContainer = Color(0xFF3FA3A3);
  static const onTertiaryFixedVariant = Color(0xFF004F4F);

  static const surface = Color(0xFFFCF9F6);
  static const surfaceBright = Color(0xFFFCF9F6);
  static const surfaceDim = Color(0xFFDCDAD7);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF6F3F0);
  static const surfaceContainer = Color(0xFFF0EDEA);
  static const surfaceContainerHigh = Color(0xFFEAE8E5);
  static const surfaceContainerHighest = Color(0xFFE5E2DF);

  static const onSurface = Color(0xFF1C1C1A);
  static const onSurfaceVariant = Color(0xFF54433E);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onSecondary = Color(0xFFFFFFFF);
  static const onTertiary = Color(0xFFFFFFFF);

  static const outline = Color(0xFF87736D);
  static const outlineVariant = Color(0xFFDAC1BA);

  static const error = Color(0xFFBA1A1A);

  // ─── Gradients ───────────────────────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  // ─── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryFixed,
        onPrimaryContainer: Color(0xFF551905),
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: Color(0xFF7A5245),
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: Color(0xFF003434),
        error: error,
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF93000A),
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF31302F),
        onInverseSurface: Color(0xFFF3F0ED),
        inversePrimary: Color(0xFFFFB59E),
      ),
      scaffoldBackgroundColor: surface,
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
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
        fillColor: surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryContainer, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: onSurfaceVariant,
        ),
      ),
    );
    return base;
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.notoSerif(
        fontSize: 57, fontWeight: FontWeight.w600, color: onSurface,
        fontStyle: FontStyle.italic,
      ),
      displayMedium: GoogleFonts.notoSerif(
        fontSize: 45, fontWeight: FontWeight.w600, color: onSurface,
      ),
      displaySmall: GoogleFonts.notoSerif(
        fontSize: 36, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineLarge: GoogleFonts.notoSerif(
        fontSize: 32, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineMedium: GoogleFonts.notoSerif(
        fontSize: 28, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineSmall: GoogleFonts.notoSerif(
        fontSize: 24, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: onSurface,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: onSurface,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: onSurface,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w700, color: onSurface,
        letterSpacing: 1.5,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w600, color: onSurface,
        letterSpacing: 1.5,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11, fontWeight: FontWeight.w600, color: onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }
}
