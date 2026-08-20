import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/update_checker_provider.dart';
import '../theme/app_theme.dart';

/// Dismissible strip shown when a newer MiarhPen release is available,
/// per [updateCheckProvider]. Silent (renders nothing) while checking, on
/// any check failure, or once dismissed for this app session — dismissing
/// is intentionally not persisted across restarts, since a still-pending
/// update is worth surfacing again next time the app is opened rather
/// than being silenced forever.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final updateAsync = ref.watch(updateCheckProvider);
    final info = updateAsync.value;
    if (info == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.primaryContainer,
      child: Row(
        children: [
          const Icon(
            Icons.system_update_alt,
            size: 20,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Update available: v${info.latestVersion} (you have '
              'v${info.currentVersion})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(info.apkDownloadUrl ?? info.releaseUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Update'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.primaryDark,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}
