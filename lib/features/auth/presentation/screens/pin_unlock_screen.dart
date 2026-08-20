import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/pin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/auth_provider.dart';

class PinUnlockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onUsePasswordInstead;

  const PinUnlockScreen({
    super.key,
    required this.onUnlocked,
    required this.onUsePasswordInstead,
  });

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  final _pinController = TextEditingController();
  bool _submitting = false;
  String? _errorText;
  bool _lockedOut = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await ref
        .read(biometricServiceProvider)
        .canCheckBiometrics();
    if (!mounted) return;
    setState(() => _canCheckBiometrics = available);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text;
    if (!PinService.isValidPinFormat(pin)) {
      setState(() => _errorText = 'Enter your PIN');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final success = await ref
        .read(authControllerProvider.notifier)
        .unlockWithPin(pin);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      widget.onUnlocked();
      return;
    }
    final attempts = await ref.read(pinServiceProvider).getFailedAttempts();
    if (!mounted) return;
    setState(() {
      _pinController.clear();
      if (attempts >= PinService.maxTrackedAttempts) {
        _lockedOut = true;
        _errorText = 'Too many failed attempts. Please use your password.';
      } else {
        _errorText = 'Incorrect PIN';
      }
    });
  }

  Future<void> _useBiometrics() async {
    setState(() => _submitting = true);
    final success = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometric();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LoadingOverlay(
          visible: _submitting,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Enter your PIN',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      enabled: !_lockedOut,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: AppConstants.maxPinLength,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'PIN'),
                      onSubmitted: (_) => _lockedOut ? null : _submit(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorText!,
                        style: const TextStyle(color: AppColors.expense),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (!_lockedOut)
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: const Text('Unlock'),
                      ),
                    if (_canCheckBiometrics && !_lockedOut) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _useBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Use biometrics'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : widget.onUsePasswordInstead,
                      child: const Text('Use password instead'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
