import 'package:flutter/material.dart';

// ── Theme option enum ──────────────────────────────────────────────────────────

enum AppThemeOption { hearth, midnight, forest, ocean, blush }

extension AppThemeOptionExt on AppThemeOption {
  String get displayName {
    switch (this) {
      case AppThemeOption.hearth:   return 'Hearth';
      case AppThemeOption.midnight: return 'Midnight';
      case AppThemeOption.forest:   return 'Forest';
      case AppThemeOption.ocean:    return 'Ocean';
      case AppThemeOption.blush:    return 'Blush';
    }
  }

  String get emoji {
    switch (this) {
      case AppThemeOption.hearth:   return '🔥';
      case AppThemeOption.midnight: return '🌙';
      case AppThemeOption.forest:   return '🌿';
      case AppThemeOption.ocean:    return '🌊';
      case AppThemeOption.blush:    return '🌸';
    }
  }
}

// ── Theme Palette ──────────────────────────────────────────────────────────────

class ZunoThemePalette {
  final AppThemeOption option;
  final Brightness brightness;

  // Brand Colors
  final Color primary;
  final Color primaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color secondary;
  final Color secondaryContainer;
  final Color tertiary;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color tertiaryContainer;
  final Color onTertiaryFixedVariant;

  // Surface Colors
  final Color surface;
  final Color surfaceBright;
  final Color surfaceDim;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  // On-color
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onPrimary;
  final Color onSecondary;
  final Color onTertiary;

  // Outline
  final Color outline;
  final Color outlineVariant;

  // Error
  final Color error;

  const ZunoThemePalette({
    required this.option,
    required this.brightness,
    required this.primary,
    required this.primaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.secondary,
    required this.secondaryContainer,
    required this.tertiary,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.tertiaryContainer,
    required this.onTertiaryFixedVariant,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceDim,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onPrimary,
    required this.onSecondary,
    required this.onTertiary,
    required this.outline,
    required this.outlineVariant,
    required this.error,
  });

  static ZunoThemePalette forOption(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.hearth:   return hearth;
      case AppThemeOption.midnight: return midnight;
      case AppThemeOption.forest:   return forest;
      case AppThemeOption.ocean:    return ocean;
      case AppThemeOption.blush:    return blush;
    }
  }

  // ── Palettes ────────────────────────────────────────────────────────────────

  static const hearth = ZunoThemePalette(
    option: AppThemeOption.hearth,
    brightness: Brightness.light,
    primary:                  Color(0xFF944931),
    primaryContainer:         Color(0xFFD67D61),
    primaryFixed:             Color(0xFFFFDBD0),
    primaryFixedDim:          Color(0xFFFFB59E),
    secondary:                Color(0xFF7D5548),
    secondaryContainer:       Color(0xFFFEC8B8),
    tertiary:                 Color(0xFF006A6A),
    tertiaryFixed:            Color(0xFF93F2F2),
    tertiaryFixedDim:         Color(0xFF76D6D5),
    tertiaryContainer:        Color(0xFF3FA3A3),
    onTertiaryFixedVariant:   Color(0xFF004F4F),
    surface:                  Color(0xFFFCF9F6),
    surfaceBright:            Color(0xFFFCF9F6),
    surfaceDim:               Color(0xFFDCDAD7),
    surfaceContainerLowest:   Color(0xFFFFFFFF),
    surfaceContainerLow:      Color(0xFFF6F3F0),
    surfaceContainer:         Color(0xFFF0EDEA),
    surfaceContainerHigh:     Color(0xFFEAE8E5),
    surfaceContainerHighest:  Color(0xFFE5E2DF),
    onSurface:                Color(0xFF1C1C1A),
    onSurfaceVariant:         Color(0xFF54433E),
    onPrimary:                Color(0xFFFFFFFF),
    onSecondary:              Color(0xFFFFFFFF),
    onTertiary:               Color(0xFFFFFFFF),
    outline:                  Color(0xFF87736D),
    outlineVariant:           Color(0xFFDAC1BA),
    error:                    Color(0xFFBA1A1A),
  );

  static const midnight = ZunoThemePalette(
    option: AppThemeOption.midnight,
    brightness: Brightness.dark,
    primary:                  Color(0xFF818CF8),
    primaryContainer:         Color(0xFF6366F1),
    primaryFixed:             Color(0xFF312E81),
    primaryFixedDim:          Color(0xFF4338CA),
    secondary:                Color(0xFFA5B4FC),
    secondaryContainer:       Color(0xFF3730A3),
    tertiary:                 Color(0xFF34D399),
    tertiaryFixed:            Color(0xFF064E3B),
    tertiaryFixedDim:         Color(0xFF065F46),
    tertiaryContainer:        Color(0xFF059669),
    onTertiaryFixedVariant:   Color(0xFF6EE7B7),
    surface:                  Color(0xFF0F172A),
    surfaceBright:            Color(0xFF1E293B),
    surfaceDim:               Color(0xFF0A0F1E),
    surfaceContainerLowest:   Color(0xFF0A0F1E),
    surfaceContainerLow:      Color(0xFF1E293B),
    surfaceContainer:         Color(0xFF263045),
    surfaceContainerHigh:     Color(0xFF2D3A50),
    surfaceContainerHighest:  Color(0xFF334155),
    onSurface:                Color(0xFFE2E8F0),
    onSurfaceVariant:         Color(0xFF94A3B8),
    onPrimary:                Color(0xFF0F0F2E),
    onSecondary:              Color(0xFF1E1B4B),
    onTertiary:               Color(0xFF022C22),
    outline:                  Color(0xFF475569),
    outlineVariant:           Color(0xFF1E3A5F),
    error:                    Color(0xFFF87171),
  );

  static const forest = ZunoThemePalette(
    option: AppThemeOption.forest,
    brightness: Brightness.light,
    primary:                  Color(0xFF2D6A4F),
    primaryContainer:         Color(0xFF52B788),
    primaryFixed:             Color(0xFFD8F3DC),
    primaryFixedDim:          Color(0xFFB7E4C7),
    secondary:                Color(0xFF40916C),
    secondaryContainer:       Color(0xFFCCE8D5),
    tertiary:                 Color(0xFF6B4226),
    tertiaryFixed:            Color(0xFFEDD7C3),
    tertiaryFixedDim:         Color(0xFFD4A57A),
    tertiaryContainer:        Color(0xFFA0522D),
    onTertiaryFixedVariant:   Color(0xFF4A2C0E),
    surface:                  Color(0xFFF8FAF8),
    surfaceBright:            Color(0xFFF8FAF8),
    surfaceDim:               Color(0xFFD8DDD9),
    surfaceContainerLowest:   Color(0xFFFFFFFF),
    surfaceContainerLow:      Color(0xFFF2F5F2),
    surfaceContainer:         Color(0xFFECEFED),
    surfaceContainerHigh:     Color(0xFFE6EAE7),
    surfaceContainerHighest:  Color(0xFFE0E4E1),
    onSurface:                Color(0xFF1A1C1A),
    onSurfaceVariant:         Color(0xFF3D4A3E),
    onPrimary:                Color(0xFFFFFFFF),
    onSecondary:              Color(0xFFFFFFFF),
    onTertiary:               Color(0xFFFFFFFF),
    outline:                  Color(0xFF6D7A6E),
    outlineVariant:           Color(0xFFBAD0BC),
    error:                    Color(0xFFBA1A1A),
  );

  static const ocean = ZunoThemePalette(
    option: AppThemeOption.ocean,
    brightness: Brightness.light,
    primary:                  Color(0xFF1A6F9A),
    primaryContainer:         Color(0xFF3B96C4),
    primaryFixed:             Color(0xFFD6EEFA),
    primaryFixedDim:          Color(0xFFADD8F0),
    secondary:                Color(0xFF2C7DA0),
    secondaryContainer:       Color(0xFFBEDEED),
    tertiary:                 Color(0xFF005F73),
    tertiaryFixed:            Color(0xFFB5E4F4),
    tertiaryFixedDim:         Color(0xFF94D0E7),
    tertiaryContainer:        Color(0xFF0A9396),
    onTertiaryFixedVariant:   Color(0xFF003A45),
    surface:                  Color(0xFFF5F9FC),
    surfaceBright:            Color(0xFFF5F9FC),
    surfaceDim:               Color(0xFFD6DDE2),
    surfaceContainerLowest:   Color(0xFFFFFFFF),
    surfaceContainerLow:      Color(0xFFEEF4F8),
    surfaceContainer:         Color(0xFFE8EFF4),
    surfaceContainerHigh:     Color(0xFFE2EAF0),
    surfaceContainerHighest:  Color(0xFFDCE5EC),
    onSurface:                Color(0xFF191C1E),
    onSurfaceVariant:         Color(0xFF3A4549),
    onPrimary:                Color(0xFFFFFFFF),
    onSecondary:              Color(0xFFFFFFFF),
    onTertiary:               Color(0xFFFFFFFF),
    outline:                  Color(0xFF6A7880),
    outlineVariant:           Color(0xFFBBCDD7),
    error:                    Color(0xFFBA1A1A),
  );

  static const blush = ZunoThemePalette(
    option: AppThemeOption.blush,
    brightness: Brightness.light,
    primary:                  Color(0xFFC2677B),
    primaryContainer:         Color(0xFFE09BAA),
    primaryFixed:             Color(0xFFFFE4E9),
    primaryFixedDim:          Color(0xFFF9C0CB),
    secondary:                Color(0xFF9C5268),
    secondaryContainer:       Color(0xFFFFCDD6),
    tertiary:                 Color(0xFF7B5EA7),
    tertiaryFixed:            Color(0xFFECDDFF),
    tertiaryFixedDim:         Color(0xFFD8BAFF),
    tertiaryContainer:        Color(0xFFB08EC6),
    onTertiaryFixedVariant:   Color(0xFF3A1B5A),
    surface:                  Color(0xFFFDF7F9),
    surfaceBright:            Color(0xFFFDF7F9),
    surfaceDim:               Color(0xFFDDD7D9),
    surfaceContainerLowest:   Color(0xFFFFFFFF),
    surfaceContainerLow:      Color(0xFFF7F1F3),
    surfaceContainer:         Color(0xFFF1EBED),
    surfaceContainerHigh:     Color(0xFFEBE5E8),
    surfaceContainerHighest:  Color(0xFFE5E0E2),
    onSurface:                Color(0xFF1E1A1B),
    onSurfaceVariant:         Color(0xFF4D3F43),
    onPrimary:                Color(0xFFFFFFFF),
    onSecondary:              Color(0xFFFFFFFF),
    onTertiary:               Color(0xFFFFFFFF),
    outline:                  Color(0xFF807378),
    outlineVariant:           Color(0xFFD9C3C8),
    error:                    Color(0xFFBA1A1A),
  );
}
