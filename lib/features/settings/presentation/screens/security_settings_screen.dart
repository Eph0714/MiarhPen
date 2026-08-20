import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/db/daos/user_dao.dart';
import '../../../../core/platform/battery_optimization_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/application/auth_provider.dart';

const _sessionTimeoutOptions = [1, 5, 10, 15, 30];

/// Security settings: PIN setup/change/remove, biometric toggle, and
/// session timeout.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _busy = false;
  final _batteryOptimizationService = BatteryOptimizationService();
  bool? _isIgnoringBatteryOptimizations;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _refreshBatteryOptimizationStatus();
    }
  }

  Future<void> _refreshBatteryOptimizationStatus() async {
    final result = await _batteryOptimizationService
        .isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _isIgnoringBatteryOptimizations = result);
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    await _batteryOptimizationService.requestIgnoreBatteryOptimizations();
    // The system dialog runs outside our control flow; re-check shortly
    // after in case the user granted it immediately.
    await Future<void>.delayed(const Duration(seconds: 1));
    await _refreshBatteryOptimizationStatus();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _promptForPin(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: AppConstants.maxPinLength,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupOrChangePin() async {
    final pin = await _promptForPin('Enter New PIN');
    if (pin == null || pin.isEmpty) return;
    if (pin.length < AppConstants.minPinLength ||
        pin.length > AppConstants.maxPinLength) {
      _showMessage(
        'PIN must be ${AppConstants.minPinLength}-${AppConstants.maxPinLength} digits.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).setupPin(pin);
      _showMessage('PIN saved.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePin() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove PIN',
      message: 'You will only be able to unlock with your password. Continue?',
      destructive: true,
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).disablePin();
      _showMessage('PIN removed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      final biometricService = ref.read(biometricServiceProvider);
      final available = await biometricService.canCheckBiometrics();
      if (!available) {
        _showMessage(
          'Biometric authentication is not available on this device.',
        );
        return;
      }
    }
    await ref
        .read(authControllerProvider.notifier)
        .setBiometricEnabled(enabled);
  }

  Future<void> _updateSessionTimeout(int minutes) async {
    final user = ref.read(authControllerProvider).user;
    if (user?.id == null) return;
    await UserDao().updateSessionTimeout(user!.id!, minutes);
    ref.invalidate(currentUserProvider);
    _showMessage('Session timeout updated.');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final user = authState.user;
    final hasPin = user?.pinHash != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('PIN', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPin
                      ? 'A PIN is set up for quick unlock.'
                      : 'Set up a PIN for quick unlock.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ElevatedButton(
                      onPressed: _busy ? null : _setupOrChangePin,
                      child: Text(hasPin ? 'Change PIN' : 'Set Up PIN'),
                    ),
                    if (hasPin)
                      OutlinedButton(
                        onPressed: _busy ? null : _removePin,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.expense),
                          foregroundColor: AppColors.expense,
                        ),
                        child: const Text('Remove PIN'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Biometric Unlock',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Biometric Unlock'),
              value: user?.biometricEnabled ?? false,
              onChanged: _toggleBiometric,
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Session Timeout',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: currentUserAsync.when(
              data: (dbUser) {
                final currentTimeout =
                    dbUser?.sessionTimeoutMin ??
                    AppConstants.defaultSessionTimeoutMinutes;
                final dropdownValue =
                    _sessionTimeoutOptions.contains(currentTimeout)
                    ? currentTimeout
                    : AppConstants.defaultSessionTimeoutMinutes;
                return Row(
                  children: [
                    const Expanded(child: Text('Lock after inactivity')),
                    DropdownButton<int>(
                      value: dropdownValue,
                      items: _sessionTimeoutOptions
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text('$m min'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _updateSessionTimeout(value);
                      },
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Unable to load session timeout.'),
            ),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Background Reliability',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isIgnoringBatteryOptimizations == true
                        ? 'MiarhPen is exempt from battery optimization — the app should stay responsive.'
                        : 'Some phones aggressively suspend apps in the background, which can make MiarhPen seem unresponsive. Exempt it from battery optimization for reliable behavior.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_isIgnoringBatteryOptimizations != true) ...[
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _requestBatteryOptimizationExemption,
                      child: const Text('Allow Unrestricted Background Use'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
