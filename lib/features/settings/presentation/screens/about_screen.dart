import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// About screen: app identity, version, and a short privacy blurb.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet, size: 48, color: AppColors.primary),
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
