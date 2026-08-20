import 'package:flutter/material.dart';

/// One brightness variant's full color set. Both [_lightPalette] and
/// [_darkPalette] below are plain compile-time constants — [AppTheme.light]
/// / [AppTheme.dark] build their [ThemeData] directly from these, never
/// through the dynamic [AppColors] getters (that would be circular: the
/// active [AppColors] palette is decided by which [ThemeData] ended up
/// resolved, so the [ThemeData] itself can't depend on it).
class _Palette {
  const _Palette({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryContainer,
    required this.income,
    required this.expense,
    required this.liability,
    required this.transfer,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryContainer;
  final Color income;
  final Color expense;
  final Color liability;
  final Color transfer;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
}

const _lightPalette = _Palette(
  primary: Color(0xFF0F7A4F), // deep professional green
  primaryDark: Color(0xFF0A5A3A),
  primaryLight: Color(0xFF3FA377),
  primaryContainer: Color(0xFFDCF3E7),
  income: Color(0xFF12805A), // money IN
  expense: Color(0xFFB3261E), // money OUT
  liability: Color(0xFFB36B00), // credit card outstanding
  transfer: Color(0xFF3B6EDB), // neutral transfer blue-gray
  background: Color(0xFFFAFCFB),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF1F6F3),
  border: Color(0xFFE1E8E4),
  textPrimary: Color(0xFF14231C),
  textSecondary: Color(0xFF5B6B63),
  textOnPrimary: Color(0xFFFFFFFF),
);

// Same green identity, re-tuned for dark surfaces: brighter/more saturated
// accent colors so they stay legible at low luminance, and a near-black
// (not pure-black) background/surface pair so cards still read as raised.
const _darkPalette = _Palette(
  primary: Color(0xFF34C38F),
  primaryDark: Color(0xFF1F8F63),
  primaryLight: Color(0xFF6FE3B3),
  primaryContainer: Color(0xFF14402C),
  income: Color(0xFF34C38F),
  expense: Color(0xFFFF6B60),
  liability: Color(0xFFFFB65C),
  transfer: Color(0xFF7EA6FF),
  background: Color(0xFF0E1512),
  surface: Color(0xFF16211C),
  surfaceMuted: Color(0xFF1D2A23),
  border: Color(0xFF2B3A32),
  textPrimary: Color(0xFFEAF2ED),
  textSecondary: Color(0xFF9FB3A8),
  textOnPrimary: Color(0xFF0A150F),
);

/// MiarhPen — professional Green + White (and Green + Near-Black in dark
/// mode) financial app theme.
///
/// Design goals: clean, modern, professional, minimal color usage,
/// rounded cards, large readable balance figures, subtle
/// (implicit-only) animation.
///
/// Every color used throughout the app's own widgets — outside of what
/// Flutter's [ThemeData] already drives automatically (`Card`, buttons,
/// `AppBar`, dividers, inputs, dialogs, snackbars, bottom nav) — reads
/// through these getters rather than a hardcoded constant, so it follows
/// [AppTheme.light] / [AppTheme.dark] instead of always looking like
/// light mode. [setBrightness] is called once per frame from
/// `MaterialApp.router`'s `builder:` (see app.dart), always in sync with
/// whichever theme actually got resolved (including `ThemeMode.system`).
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;

  /// Called from the app root every rebuild with the [ThemeData] Flutter
  /// actually resolved (accounts for `ThemeMode.system` automatically) —
  /// never call this from anywhere else.
  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static _Palette get _p =>
      _brightness == Brightness.dark ? _darkPalette : _lightPalette;

  static Color get primary => _p.primary;
  static Color get primaryDark => _p.primaryDark;
  static Color get primaryLight => _p.primaryLight;
  static Color get primaryContainer => _p.primaryContainer;

  static Color get income => _p.income;
  static Color get expense => _p.expense;
  static Color get liability => _p.liability;
  static Color get transfer => _p.transfer;

  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceMuted => _p.surfaceMuted;
  static Color get border => _p.border;
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textOnPrimary => _p.textOnPrimary;
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

  static ThemeData get light => _build(_lightPalette, Brightness.light);
  static ThemeData get dark => _build(_darkPalette, Brightness.dark);

  static ThemeData _build(_Palette p, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.textOnPrimary,
      primaryContainer: p.primaryContainer,
      surface: p.surface,
      error: p.expense,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: 'Roboto',
    );

    final textTheme = base.textTheme
        .copyWith(
          // Large, readable balance figures (Dashboard headline numbers).
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 40,
            color: p.textPrimary,
            letterSpacing: -0.5,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 30,
            color: p.textPrimary,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(color: p.textPrimary),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: p.textSecondary,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(fontFamily: 'Roboto');

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary, width: 1.4),
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
          foregroundColor: p.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceMuted,
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
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          borderSide: BorderSide(color: p.expense, width: 1.4),
        ),
        labelStyle: TextStyle(color: p.textSecondary),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surfaceMuted,
        selectedColor: p.primaryContainer,
        labelStyle: TextStyle(color: p.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          side: BorderSide(color: p.border),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle: TextStyle(color: p.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
      colorScheme: colorScheme,
    );
  }
}
