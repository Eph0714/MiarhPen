import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../application/auth_provider.dart';

/// Shows a confirm dialog and, if confirmed, logs the user out.
Future<void> confirmAndLogout(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onLoggedOut,
}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Log Out',
    message: 'Are you sure you want to log out?',
    destructive: false,
  );
  if (!confirmed) return;
  await ref.read(authControllerProvider.notifier).logout();
  onLoggedOut();
}
