import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/security/pin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const PinSetupScreen({super.key, required this.onDone, required this.onSkip});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePin(String? value) {
    if (value == null || value.isEmpty) return 'PIN is required';
    if (!PinService.isValidPinFormat(value)) {
      return 'PIN must be ${AppConstants.minPinLength}-${AppConstants.maxPinLength} digits';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pinController.text != _confirmController.text) {
      setState(() => _errorText = 'PINs do not match');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    await ref
        .read(authControllerProvider.notifier)
        .setupPin(_pinController.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Set Up PIN')),
      body: LoadingOverlay(
        visible: _submitting,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create a PIN for quick access to MiarhPen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: AppConstants.maxPinLength,
                  decoration: const InputDecoration(labelText: 'Enter PIN'),
                  validator: _validatePin,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: AppConstants.maxPinLength,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                  validator: _validatePin,
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
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: const Text('Save PIN'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _submitting ? null : widget.onSkip,
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
