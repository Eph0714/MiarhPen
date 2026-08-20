import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/auth_provider.dart';

class BiometricPromptScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onFallbackToPin;

  const BiometricPromptScreen({
    super.key,
    required this.onUnlocked,
    required this.onFallbackToPin,
  });

  @override
  ConsumerState<BiometricPromptScreen> createState() =>
      _BiometricPromptScreenState();
}

class _BiometricPromptScreenState extends ConsumerState<BiometricPromptScreen> {
  bool _authenticating = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    final success = await ref
        .read(authControllerProvider.notifier)
        .unlockWithBiometric();
    if (!mounted) return;
    if (success) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _authenticating = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint, size: 72, color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _authenticating
                      ? 'Authenticating...'
                      : 'Authentication failed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_failed) ...[
                  ElevatedButton(
                    onPressed: _attempt,
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: widget.onFallbackToPin,
                    child: const Text('Use PIN instead'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
