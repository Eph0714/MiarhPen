import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/platform/app_updater_service.dart';
import '../../../../core/platform/update_checker_provider.dart';
import '../../../../core/platform/update_checker_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// About screen: app identity, version, update status, and a short
/// privacy blurb.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  final _updater = AppUpdaterService();
  bool _updating = false;

  /// Silently downloads the update and hands it to Android's own package
  /// installer — no browser, no separate download page. Android still
  /// shows its own one-tap "Install app?" confirmation once the download
  /// finishes; that step belongs to the OS and can't be skipped.
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

  String _linkFor(UpdateInfo info) => info.apkDownloadUrl ?? info.releaseUrl;

  Future<void> _shareLink(UpdateInfo info) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _linkFor(info),
        subject: '${AppConstants.appName} v${info.latestVersion}',
      ),
    );
  }

  Future<void> _copyLink(UpdateInfo info) async {
    await Clipboard.setData(ClipboardData(text: _linkFor(info)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final updateAsync = ref.watch(updateCheckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppConstants.tagline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                        : '...';
                    return Text(
                      version,
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppConstants.poweredBy,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  AppConstants.establishedYear,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Software Update',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                tooltip: 'Check now',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.invalidate(updateCheckProvider),
              ),
            ],
          ),
          AppCard(
            child: updateAsync.when(
              loading: () => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Checking for updates…'),
                ],
              ),
              error: (err, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: AppColors.expense),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Unable to check for updates: '
                      '${err.toString().replaceFirst('Exception: ', '')}',
                    ),
                  ),
                ],
              ),
              data: (info) {
                if (info == null) {
                  return Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('You\'re on the latest version.'),
                    ],
                  );
                }
                final link = _linkFor(info);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.system_update_alt,
                          color: AppColors.liability,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Version ${info.latestVersion} is available '
                            '(you have ${info.currentVersion}).',
                          ),
                        ),
                        FilledButton(
                          onPressed: _updating ? null : () => _update(info),
                          child: _updating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Update'),
                        ),
                      ],
                    ),
                    if (info.releaseNotes != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'What\'s new',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        info.releaseNotes!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Download Link',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            link,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy link',
                          icon: const Icon(Icons.copy_outlined, size: 20),
                          onPressed: () => _copyLink(info),
                        ),
                        IconButton(
                          tooltip: 'Share link',
                          icon: const Icon(Icons.share_outlined, size: 20),
                          onPressed: () => _shareLink(info),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Privacy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Text(
              '${AppConstants.appName} stores all of your data locally on '
              'this device — nothing is sent to any server. Your income, '
              'expenses, accounts, and categories never leave your device '
              'unless you choose to export or share a backup yourself. '
              'Backups you create are your responsibility to store safely; '
              '${AppConstants.appName} does not keep a copy of them anywhere else.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
