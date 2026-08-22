import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_updater_service.dart';
import '../platform/update_checker_provider.dart';
import '../platform/update_checker_service.dart';
import '../theme/app_theme.dart';

/// Strip shown at the top of the Dashboard when a newer MiarhPen release
/// is available, per [updateCheckProvider] — silent (renders nothing)
/// while checking, on any check failure, or once dismissed for this app
/// session. Tapping "Update" downloads the APK in-app and hands it
/// straight to Android's own package installer (same flow as Settings >
/// About) — no browser tab, no separate download page.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  final _updater = AppUpdaterService();
  bool _dismissed = false;
  bool _updating = false;

  Future<void> _update(UpdateInfo info) async {
    setState(() => _updating = true);
    final started = await _updater.downloadAndInstall(info);
    if (!mounted) return;
    setState(() => _updating = false);
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not download the update. Check your connection.',
          ),
        ),
      );
    }
  }

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
          Icon(Icons.system_update_alt, size: 20, color: AppColors.primaryDark),
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
            onPressed: _updating ? null : () => _update(info),
            child: _updating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryDark,
                    ),
                  )
                : const Text('Update'),
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
