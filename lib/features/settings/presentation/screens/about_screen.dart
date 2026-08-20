import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/platform/update_checker_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// About screen: app identity, version, update status, and a short
/// privacy blurb.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                const Icon(
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
          Text(
            'Software Update',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
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
              error: (_, __) => const Text('Unable to check for updates.'),
              data: (info) {
                if (info == null) {
                  return const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text('You\'re on the latest version.'),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Icon(
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
                      onPressed: () => launchUrl(
                        Uri.parse(info.apkDownloadUrl ?? info.releaseUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Update'),
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
