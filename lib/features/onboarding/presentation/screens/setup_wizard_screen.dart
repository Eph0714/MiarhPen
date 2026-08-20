import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../application/setup_wizard_provider.dart';

class _CurrencyOption {
  final String code;
  final String symbol;
  final String label;

  const _CurrencyOption(this.code, this.symbol, this.label);
}

const _currencyOptions = [
  _CurrencyOption('PHP', '₱', 'Philippine Peso (₱)'),
  _CurrencyOption('USD', '\$', 'US Dollar (\$)'),
  _CurrencyOption('EUR', '€', 'Euro (€)'),
];

/// First-run setup wizard: credentials -> currency -> accounting period ->
/// initial accounts -> review & confirm.
class SetupWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const SetupWizardScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  static const int _stepCount = 5;

  final _pageController = PageController();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _periodNameController = TextEditingController();

  final _newAccountNameController = TextEditingController();
  final _newAccountBalanceController = TextEditingController();
  AccountType _newAccountType = AccountType.cash;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _finishing = false;
  String? _finishError;

  @override
  void initState() {
    super.initState();
    final initialState = ref.read(setupWizardControllerProvider);
    _periodNameController.text = initialState.periodName;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _periodNameController.dispose();
    _newAccountNameController.dispose();
    _newAccountBalanceController.dispose();
    super.dispose();
  }

  bool _isStepValid(int step, SetupWizardState state) {
    switch (step) {
      case 0:
        return _usernameController.text.trim().isNotEmpty &&
            _passwordController.text.length >= 4 &&
            _passwordController.text == _confirmPasswordController.text;
      case 1:
        return true;
      case 2:
        return _periodNameController.text.trim().isNotEmpty;
      case 3:
        return state.initialAccounts.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _goNext(SetupWizardState state) {
    final controller = ref.read(setupWizardControllerProvider.notifier);
    if (state.step == 0) {
      controller.setCredentials(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
    } else if (state.step == 2) {
      controller.setPeriod(periodName: _periodNameController.text.trim());
    }
    controller.nextStep();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goBack(SetupWizardState state) {
    ref.read(setupWizardControllerProvider.notifier).previousStep();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _addAccount(SetupWizardState state) {
    final name = _newAccountNameController.text.trim();
    final balance = double.tryParse(_newAccountBalanceController.text.trim());
    if (name.isEmpty || balance == null) return;
    ref.read(setupWizardControllerProvider.notifier).addInitialAccount(
          InitialAccountDraft(
            name: name,
            type: _newAccountType,
            beginningBalance: balance,
          ),
        );
    _newAccountNameController.clear();
    _newAccountBalanceController.clear();
    setState(() {});
  }

  Future<void> _finish() async {
    setState(() {
      _finishing = true;
      _finishError = null;
    });
    try {
      await ref.read(setupWizardControllerProvider.notifier).completeSetup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishError = 'Setup failed: $e');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupWizardControllerProvider);
    final canProceed = _isStepValid(state.step, state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Welcome to MiarhPen'),
        automaticallyImplyLeading: false,
      ),
      body: LoadingOverlay(
        visible: _finishing,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: LinearProgressIndicator(
                value: (state.step + 1) / _stepCount,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.primary,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _CredentialsStep(
                    usernameController: _usernameController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    obscureConfirmPassword: _obscureConfirmPassword,
                    onToggleObscurePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleObscureConfirmPassword: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    onChanged: () => setState(() {}),
                  ),
                  _CurrencyStep(state: state),
                  _PeriodStep(
                    periodNameController: _periodNameController,
                    state: state,
                    onChanged: () => setState(() {}),
                  ),
                  _AccountsStep(
                    state: state,
                    nameController: _newAccountNameController,
                    balanceController: _newAccountBalanceController,
                    selectedType: _newAccountType,
                    onTypeChanged: (type) =>
                        setState(() => _newAccountType = type),
                    onAdd: () => _addAccount(state),
                  ),
                  _ReviewStep(
                    state: state,
                    username: _usernameController.text.trim(),
                    error: _finishError,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (state.step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _finishing ? null : () => _goBack(state),
                        child: const Text('Back'),
                      ),
                    ),
                  if (state.step > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _finishing
                          ? null
                          : !canProceed
                              ? null
                              : state.step == _stepCount - 1
                                  ? _finish
                                  : () => _goNext(state),
                      child: Text(
                        state.step == _stepCount - 1 ? 'Finish Setup' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialsStep extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onToggleObscureConfirmPassword;
  final VoidCallback onChanged;

  const _CredentialsStep({
    required this.usernameController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onToggleObscurePassword,
    required this.onToggleObscureConfirmPassword,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create your account', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Set a username and password to secure MiarhPen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscurePassword,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleObscureConfirmPassword,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
          if (passwordController.text.isNotEmpty &&
              confirmPasswordController.text.isNotEmpty &&
              passwordController.text != confirmPasswordController.text) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Passwords do not match',
              style: TextStyle(color: AppColors.expense),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrencyStep extends ConsumerWidget {
  final SetupWizardState state;

  const _CurrencyStep({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose your currency', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This will be used throughout MiarhPen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: state.currencyCode,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: _currencyOptions
                .map(
                  (o) => DropdownMenuItem(value: o.code, child: Text(o.label)),
                )
                .toList(),
            onChanged: (code) {
              if (code == null) return;
              final option = _currencyOptions.firstWhere((o) => o.code == code);
              ref
                  .read(setupWizardControllerProvider.notifier)
                  .setCurrency(option.code, option.symbol);
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodStep extends StatelessWidget {
  final TextEditingController periodNameController;
  final SetupWizardState state;
  final VoidCallback onChanged;

  const _PeriodStep({
    required this.periodNameController,
    required this.state,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'First accounting period',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Give your first period a name and start date.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: periodNameController,
                decoration: const InputDecoration(labelText: 'Period Name'),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.periodStartDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    ref
                        .read(setupWizardControllerProvider.notifier)
                        .setPeriod(periodStartDate: picked);
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${state.periodStartDate.year}-${state.periodStartDate.month.toString().padLeft(2, '0')}-${state.periodStartDate.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountsStep extends ConsumerWidget {
  final SetupWizardState state;
  final TextEditingController nameController;
  final TextEditingController balanceController;
  final AccountType selectedType;
  final ValueChanged<AccountType> onTypeChanged;
  final VoidCallback onAdd;

  const _AccountsStep({
    required this.state,
    required this.nameController,
    required this.balanceController,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Initial accounts',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add at least one account with its beginning balance.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < state.initialAccounts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.initialAccounts[i].name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${state.initialAccounts[i].type.label} · ${CurrencyFormatter.format(state.initialAccounts[i].beginningBalance, symbol: state.currencySymbol)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.expense),
                      onPressed: () => ref
                          .read(setupWizardControllerProvider.notifier)
                          .removeInitialAccount(i),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Account Name'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<AccountType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: AccountType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (t) {
                    if (t != null) onTypeChanged(t);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Beginning Balance'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () {
                    if (Validators.required(nameController.text, fieldName: 'Account name') != null) {
                      return;
                    }
                    if (Validators.positiveAmount(balanceController.text) != null) {
                      return;
                    }
                    onAdd();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final SetupWizardState state;
  final String username;
  final String? error;

  const _ReviewStep({required this.state, required this.username, this.error});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review & confirm', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Username', value: username),
                _ReviewRow(label: 'Currency', value: '${state.currencyCode} (${state.currencySymbol})'),
                _ReviewRow(label: 'First Period', value: state.periodName),
                _ReviewRow(
                  label: 'Start Date',
                  value:
                      '${state.periodStartDate.year}-${state.periodStartDate.month.toString().padLeft(2, '0')}-${state.periodStartDate.day.toString().padLeft(2, '0')}',
                ),
                _ReviewRow(
                  label: 'Beginning Balance',
                  value: CurrencyFormatter.format(
                    state.beginningBalanceTotal,
                    symbol: state.currencySymbol,
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                Text('Accounts (${state.initialAccounts.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final account in state.initialAccounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '${account.name} — ${account.type.label} — ${CurrencyFormatter.format(account.beginningBalance, symbol: state.currencySymbol)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(error!, style: const TextStyle(color: AppColors.expense)),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
