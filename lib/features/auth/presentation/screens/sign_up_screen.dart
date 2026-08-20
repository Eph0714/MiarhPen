import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/auth_provider.dart';

/// Lets an additional household/team member create their own login.
/// MiarhPen shares one set of accounts/transactions/categories across
/// everyone who signs up — this screen only collects credentials, not a
/// full financial setup (that already happened during onboarding).
class SignUpScreen extends ConsumerStatefulWidget {
  final VoidCallback onSignUpSuccess;
  final VoidCallback onCancel;

  const SignUpScreen({
    super.key,
    required this.onSignUpSuccess,
    required this.onCancel,
  });

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .signUp(_usernameController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error == null) {
      widget.onSignUpSuccess();
    } else {
      setState(() => _errorText = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: LoadingOverlay(
          visible: _submitting,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Join ${AppConstants.appName}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Create your own login. You\'ll see the same accounts and transactions as everyone else on this device.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            Validators.required(value, fieldName: 'Username'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
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
                        child: const Text('CREATE ACCOUNT'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _submitting ? null : widget.onCancel,
                        child: const Text('Already have an account? Log In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
