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

  /// Movie title under a poster.
  static const Color posterTitle = Color(0xFFAFB0B0);

  /// Release year under a poster.
  static const Color posterYear = Color(0xFF62605D);

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
  static const double sideRailWidth = 80;

  /// Size of a rail button.
  static const double railButton = 48;
}

/// Text styles for the title and year shown under poster cards.
///
/// Derived from the theme's text styles (so the typeface and weight are kept)
/// with a slightly smaller size and a tighter line height, so the year sits
/// closer to the title. The global `TextTheme` is left untouched.
abstract final class PosterCaption {
  static TextStyle? title(TextTheme textTheme) => textTheme.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.2,
        color: AppColors.posterTitle,
      );

  static TextStyle? year(TextTheme textTheme) => textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.2,
        color: AppColors.posterYear,
      );
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
      // UI typeface (IBM Plex Sans), with a system fallback stack.
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: const ['Segoe UI', 'Roboto'],
      // Desktop platforms default to `VisualDensity.compact`, which shrinks
      // every Material component by 8 logical pixels. The reference UI uses
      // full-size controls, so `standard` is pinned here.
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        // Body text uses Medium (500) as its base weight.
        bodyLarge: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
