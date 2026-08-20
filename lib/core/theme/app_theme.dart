import 'package:flutter/material.dart';

/// MiarhPen — professional Green + White financial app theme.
///
/// Design goals: clean, modern, professional, minimal color usage,
/// white surfaces, green primary/action color, rounded cards,
/// large readable balance figures, subtle (implicit-only) animation.
class AppColors {
  AppColors._();

  // Primary green palette
  static const Color primary = Color(0xFF0F7A4F); // deep professional green
  static const Color primaryDark = Color(0xFF0A5A3A);
  static const Color primaryLight = Color(0xFF3FA377);
  static const Color primaryContainer = Color(0xFFDCF3E7);

  // Semantic colors
  static const Color income = Color(0xFF12805A); // money IN
  static const Color expense = Color(0xFFB3261E); // money OUT
  static const Color liability = Color(0xFFB36B00); // credit card outstanding
  static const Color transfer = Color(0xFF3B6EDB); // neutral transfer blue-gray

  // Neutrals
  static const Color background = Color(0xFFFAFCFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F6F3);
  static const Color border = Color(0xFFE1E8E4);
  static const Color textPrimary = Color(0xFF14231C);
  static const Color textSecondary = Color(0xFF5B6B63);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double cardRadius = 16;
  static const double buttonRadius = 12;
  static const double chipRadius = 999;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.primaryContainer,
      surface: AppColors.surface,
      error: AppColors.expense,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    final textTheme = base.textTheme
        .copyWith(
          // Large, readable balance figures (Dashboard headline numbers).
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 40,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 30,
            color: AppColors.textPrimary,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(fontFamily: 'Roboto');

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primaryContainer,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      colorScheme: colorScheme,
    );
  }
}
