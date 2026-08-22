import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard rounded white card used throughout MiarhPen (dashboard tiles,
/// list rows, form sections). Wraps [Card] with the app's spacing/shape
/// defaults so screens don't repeat the same decoration.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Overrides the card's background — defaults to the theme's normal
  /// card color (white in light mode, near-black in dark mode) when left
  /// unset.
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      onTap: onTap,
      child: card,
    );
  }
}
