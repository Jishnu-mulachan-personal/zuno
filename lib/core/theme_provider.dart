import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import 'app_theme_data.dart';

const _kThemeKey = 'zuno_theme_option';

class ThemeNotifier extends StateNotifier<AppThemeOption> {
  ThemeNotifier() : super(AppThemeOption.hearth);

  /// Load saved theme from SharedPreferences and apply it.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemeKey);
      if (saved != null) {
        final option = AppThemeOption.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => AppThemeOption.hearth,
        );
        _apply(option);
      }
    } catch (e) {
      debugPrint('[ThemeNotifier] Failed to load theme: $e');
    }
  }

  /// Change the active theme and persist the selection.
  Future<void> selectTheme(AppThemeOption option) async {
    _apply(option);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeKey, option.name);
    } catch (e) {
      debugPrint('[ThemeNotifier] Failed to save theme: $e');
    }
  }

  void _apply(AppThemeOption option) {
    ZunoTheme.applyPalette(ZunoThemePalette.forOption(option));
    state = option;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeOption>((ref) {
  return ThemeNotifier();
});
