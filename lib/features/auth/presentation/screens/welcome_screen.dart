import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// First screen shown to anyone not logged in: a clear choice between
/// creating an account and logging into an existing one. Routing-agnostic
/// — the router decides where "Create New Account" actually leads (the
/// full first-time setup wizard if the app has never been set up, or the
/// lightweight sign-up screen if someone else already has).
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  /// Whether "Login to Existing Account" makes sense to offer — false on
  /// a completely fresh install where no account exists yet.
  final bool showLogin;

  const WelcomeScreen({
    super.key,
    required this.onCreateAccount,
    required this.onLogin,
    this.showLogin = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppConstants.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ElevatedButton(
                    onPressed: onCreateAccount,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                    ),
                    child: const Text('CREATE NEW ACCOUNT'),
                  ),
                  if (showLogin) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: onLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: const Text('LOGIN TO EXISTING ACCOUNT'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
