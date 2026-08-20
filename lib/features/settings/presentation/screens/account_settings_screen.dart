import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_confirm.dart';

/// Account settings: current username, change password, log out.
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key, this.onLoggedOut});

  /// Called after a successful logout so the caller can navigate away
  /// (e.g. back to the login screen). Optional — if omitted, this screen
  /// just pops itself.
  final VoidCallback? onLoggedOut;

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _submitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            _currentPasswordController.text,
            _newPasswordController.text,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    await confirmAndLogout(
      context,
      ref,
      onLoggedOut: () {
        if (widget.onLoggedOut != null) {
          widget.onLoggedOut!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Username',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        currentUserAsync.when(
                          data: (user) => user?.username ?? '-',
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Change Password', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current Password'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm New Password'),
                    validator: (v) {
                      if (v != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _changePassword,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary,
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: AppColors.expense),
              label: const Text('Log Out', style: TextStyle(color: AppColors.expense)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.expense),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
