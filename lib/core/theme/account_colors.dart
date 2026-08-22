import 'package:flutter/material.dart';

/// A stable, professional color per account for the Dashboard's Accounts
/// buttons — so at a glance each account reads as its own "tile" the way
/// e.g. a bank's own app color-codes card products.
///
/// The 10 hues below are spaced around the color wheel using simple color
/// theory: sample every ~35°-40° starting at blue (210°) and skipping the
/// two bands MiarhPen already uses for meaning elsewhere — green (~120°-160°,
/// [AppColors.primary]/[AppColors.income]) and red (~0°-15°/345°-360°,
/// [AppColors.expense]) — so an account's color is never mistaken for an
/// income/expense/primary-action cue. Saturation and lightness are held
/// close to constant across the set (a "tonal" palette) so no single
/// account's tile reads louder or duller than its neighbors.
class AccountColors {
  AccountColors._();

  static const List<Color> _light = [
    Color(0xFF2F6FED), // blue
    Color(0xFF7C5CFC), // indigo/violet
    Color(0xFFB23FD1), // purple
    Color(0xFFE0459B), // magenta/rose
    Color(0xFFE0894A), // amber/orange (kept well clear of expense red)
    Color(0xFFC9A227), // gold
    Color(0xFF17A2B8), // cyan/teal
    Color(0xFF0FA3A3), // deep teal
    Color(0xFF546E9C), // slate blue
    Color(0xFF8D6E63), // warm taupe
  ];

  // Same hues, lifted in lightness and eased in saturation so each stays
  // legible and un-muddy against MiarhPen's near-black dark surfaces.
  static const List<Color> _dark = [
    Color(0xFF6C9BFF),
    Color(0xFFA48CFF),
    Color(0xFFD37AEA),
    Color(0xFFF17FBE),
    Color(0xFFF2A874),
    Color(0xFFE0C15C),
    Color(0xFF5CCBDD),
    Color(0xFF4FCACA),
    Color(0xFF8AA3D6),
    Color(0xFFBBA097),
  ];

  /// Deterministic color for [accountId] — the same account always gets the
  /// same color across app restarts and re-sorted lists (unlike an
  /// index-into-the-currently-displayed-list scheme, which would reshuffle
  /// colors whenever accounts are added, removed, or resorted).
  static Color forAccount(int? accountId, Brightness brightness) {
    final palette = brightness == Brightness.dark ? _dark : _light;
    final id = accountId ?? 0;
    return palette[id % palette.length];
  }
}
