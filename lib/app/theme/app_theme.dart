import 'package:flutter/material.dart';

/// Design tokens taken from the AIOStreams reference UI.
///
/// Kept in one place so every screen reads the same values instead of
/// hard-coding colours and paddings.
abstract final class AppColors {
  /// App background, near black.
  static const Color background = Color(0xFF0A0A0C);

  /// Cards, panels and rails.
  static const Color surface = Color(0xFF151518);

  /// Hover / selected surfaces.
  static const Color surfaceHigh = Color(0xFF1F1F24);

  /// Brand accent: amber, used for focus, toggles and badges.
  static const Color accent = Color(0xFFF0A020);

  static const Color onAccent = Color(0xFF1A1200);

  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9A9AA4);

  static const Color divider = Color(0xFF26262B);
}

/// Spacing scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radii.
abstract final class AppRadii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
}

/// Sizes shared by the shell.
abstract final class AppSizes {
  /// Width of the icon-only navigation rail.
  static const double sideRailWidth = 64;

  /// Size of a rail button.
  static const double railButton = 40;
}

abstract final class AppTheme {
  /// The app's dark theme.
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.divider,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
