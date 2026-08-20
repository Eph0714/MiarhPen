import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/auth_provider.dart';

/// Login screen. The router only ever sends users here once at least one
/// account exists (see the Welcome screen and app_router's redirect
/// logic), so this screen doesn't need to guard against a userless
/// database itself.
class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onSignUp;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onSignUp,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          _usernameController.text.trim(),
          _passwordController.text,
          rememberMe: _rememberMe,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      widget.onLoginSuccess();
    } else {
      setState(() => _errorText = 'Invalid username or password');
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 56,
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
                      const SizedBox(height: AppSpacing.xl),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Username is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
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
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Password is required'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CheckboxListTile(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                        title: const Text('Remember Me'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _errorText!,
                          style: TextStyle(color: AppColors.expense),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: const Text('LOGIN'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _submitting ? null : widget.onSignUp,
                        child: const Text("Don't have an account? Sign Up"),
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
