import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Blocking loading spinner overlay, shown while a save/load operation is
/// in flight (also doubles as MiarhPen's duplicate-submit guard: while
/// visible, underlying buttons are unreachable).
class LoadingOverlay extends StatelessWidget {
  final bool visible;
  final Widget child;

  const LoadingOverlay({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }
}
