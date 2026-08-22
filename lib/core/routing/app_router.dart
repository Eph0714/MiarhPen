import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting_periods/application/periods_provider.dart';
import '../../features/accounting_periods/presentation/screens/period_detail_screen.dart';
import '../../features/accounting_periods/presentation/screens/periods_list_screen.dart';
import '../../features/accounts/application/accounts_provider.dart';
import '../../features/accounts/presentation/screens/account_detail_screen.dart';
import '../../features/accounts/presentation/screens/account_form_screen.dart';
import '../../features/accounts/presentation/screens/accounts_list_screen.dart';
import '../../features/auth/application/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/pin_setup_screen.dart';
import '../../features/auth/presentation/screens/pin_unlock_screen.dart';
import '../../features/categories/application/categories_provider.dart';
import '../../features/categories/presentation/screens/category_form_screen.dart';
import '../../features/categories/presentation/screens/category_list_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/data_management/presentation/screens/data_settings_screen.dart';
import '../../features/onboarding/presentation/screens/setup_wizard_screen.dart';
import '../../features/reports/presentation/screens/account_report_screen.dart';
import '../../features/reports/presentation/screens/account_statement_screen.dart';
import '../../features/reports/presentation/screens/expense_report_screen.dart';
import '../../features/reports/presentation/screens/financial_summary_screen.dart';
import '../../features/reports/presentation/screens/income_report_screen.dart';
import '../../features/reports/presentation/screens/daily_balance_report_screen.dart';
import '../../features/reports/presentation/screens/money_in_out_report_screen.dart';
import '../../features/reports/presentation/screens/reports_home_screen.dart';
import '../../features/recurring_payments/application/recurring_payments_provider.dart';
import '../../features/recurring_payments/presentation/screens/recurring_payment_form_screen.dart';
import '../../features/recurring_payments/presentation/screens/recurring_payments_list_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/appearance_settings_screen.dart';
import '../../features/settings/presentation/screens/account_settings_screen.dart';
import '../../features/settings/presentation/screens/accounting_settings_screen.dart';
import '../../features/settings/presentation/screens/security_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_home_screen.dart';
import '../../features/transactions/application/transaction_filter.dart';
import '../../features/transactions/application/transactions_provider.dart';
import '../../features/transactions/presentation/screens/expense_entry_screen.dart';
import '../../features/transactions/presentation/screens/income_entry_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/transactions/presentation/screens/transaction_history_screen.dart';
import '../../features/transactions/presentation/widgets/transaction_tile.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../../features/transfers/application/transfers_provider.dart';
import '../../features/transfers/presentation/screens/transfer_history_screen.dart';
import '../../features/transfers/presentation/screens/transfer_money_screen.dart';
import 'router_refresh_notifier.dart';

/// Root navigator key so pushed (non-tab) routes cover the whole screen,
/// including the bottom nav bar, rather than just the active shell branch.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Builds the app's [GoRouter] once. Kept alive for the lifetime of the
/// [ProviderScope] — `ref` inside `redirect`/route builders always reads
/// the current provider state, so there's no need to rebuild the router
/// itself when auth state changes; [RouterRefreshNotifier] just tells
/// go_router to re-run `redirect`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final currentUser = ref.read(currentUserProvider);
      final authState = ref.read(authControllerProvider);

      // All the screens a logged-out visitor is allowed to be on. Welcome
      // is the entry point (offers "Create New Account" / "Login to
      // Existing Account"); the other three are reached *from* Welcome.
      const loggedOutRoutes = {'/welcome', '/login', '/signup', '/onboarding'};

      final hasNoUser = currentUser.hasValue && currentUser.value == null;
      if (hasNoUser) {
        // With zero accounts in the whole app, only Welcome (which hides
        // its Login option in this state) and the full first-time setup
        // wizard make sense.
        if (location == '/welcome' || location == '/onboarding') return null;
        return '/welcome';
      }

      final hasUser = currentUser.hasValue && currentUser.value != null;
      if (hasUser && authState.isLoggedOut) {
        // "Remember Me" is a cold-start-only concern, resolved entirely
        // by AuthController's own background check (see
        // AuthState.autoLoginChecked's doc comment) — the redirect just
        // waits for that one-time check to finish rather than
        // re-deriving the answer itself from a live DB read, which was
        // the source of Logout occasionally appearing to silently log
        // the user back in.
        if (!authState.autoLoginChecked) {
          // Still resolving — hold position rather than momentarily
          // showing the login form only to redirect away a moment later.
          return null;
        }

        if (loggedOutRoutes.contains(location)) return null;
        return '/welcome';
      }

      if (authState.isLocked) {
        return location == '/lock' ? null : '/lock';
      }

      if (authState.isLoggedIn &&
          (loggedOutRoutes.contains(location) || location == '/lock')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) {
          final hasUser = ref.read(currentUserProvider).value != null;
          return WelcomeScreen(
            showLogin: hasUser,
            onCreateAccount: () =>
                hasUser ? context.push('/signup') : context.go('/onboarding'),
            onLogin: () => context.push('/login'),
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            SetupWizardScreen(onComplete: () => context.go('/pin-setup')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoginSuccess: () => context.go('/dashboard'),
          onSignUp: () => context.push('/signup'),
        ),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => SignUpScreen(
          onSignUpSuccess: () => context.go('/dashboard'),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => PinUnlockScreen(
          onUnlocked: () => context.go('/dashboard'),
          onUsePasswordInstead: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/pin-setup',
        builder: (context, state) => PinSetupScreen(
          onDone: () => context.go('/dashboard'),
          onSkip: () => context.go('/dashboard'),
        ),
      ),

      // Transactions
      GoRoute(
        path: '/transactions/add-income',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => IncomeEntryScreen(
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/transactions/add-expense',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ExpenseEntryScreen(
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/transactions/edit/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _TransactionEditRoute(id: id);
        },
      ),
      GoRoute(
        path: '/transactions/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransactionDetailScreen(
            transactionId: id,
            onEdit: () => context.push('/transactions/edit/$id'),
            onDeleted: () => context.pop(),
            onClose: () => context.pop(),
          );
        },
      ),

      // Transfers
      GoRoute(
        path: '/transfers/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TransferMoneyScreen(
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/transfers/edit/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _TransferEditRoute(id: id);
        },
      ),
      GoRoute(
        path: '/transfers/history',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TransferHistoryScreen(
          onTapTransfer: (t) => context.push('/transfers/edit/${t.id}'),
        ),
      ),

      // Accounts
      GoRoute(
        path: '/accounts/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccountFormScreen(
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/accounts/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _AccountEditRoute(id: id);
        },
      ),
      GoRoute(
        path: '/accounts/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AccountDetailScreen(
            accountId: id,
            transactionsSection: _AccountTransactionsSection(accountId: id),
            onEdit: () => context.push('/accounts/$id/edit'),
            onDisabled: () => context.pop(),
            onViewStatement: () => context.push('/accounts/$id/statement'),
          );
        },
      ),

      // Categories
      GoRoute(
        path: '/categories/income',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CategoryListScreen(
          isIncome: true,
          onAdd: () => context.push('/categories/income/new'),
          onEditCategory: (category) =>
              context.push('/categories/income/${category.id}/edit'),
        ),
      ),
      GoRoute(
        path: '/categories/expense',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CategoryListScreen(
          isIncome: false,
          onAdd: () => context.push('/categories/expense/new'),
          onEditCategory: (category) =>
              context.push('/categories/expense/${category.id}/edit'),
        ),
      ),
      GoRoute(
        path: '/categories/income/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CategoryFormScreen(
          isIncome: true,
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/categories/income/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _CategoryEditRoute(isIncome: true, id: id);
        },
      ),
      GoRoute(
        path: '/categories/expense/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CategoryFormScreen(
          isIncome: false,
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/categories/expense/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _CategoryEditRoute(isIncome: false, id: id);
        },
      ),

      // Accounting periods
      GoRoute(
        path: '/periods',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PeriodsListScreen(
          onTapPeriod: (period) => context.push('/periods/${period.id}'),
          onCreateNew: () => _showCreatePeriodDialog(context),
        ),
      ),
      GoRoute(
        path: '/periods/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PeriodDetailScreen(
            periodId: id,
            onClosed: () => context.pop(),
          );
        },
      ),

      // Recurring payment schedules
      GoRoute(
        path: '/recurring-payments',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RecurringPaymentsListScreen(
          onCreateNew: () => context.push('/recurring-payments/new'),
          onTapPayment: (payment) =>
              context.push('/recurring-payments/${payment.id}/edit'),
        ),
      ),
      GoRoute(
        path: '/recurring-payments/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RecurringPaymentFormScreen(
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        ),
      ),
      GoRoute(
        path: '/recurring-payments/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return Consumer(
            builder: (context, ref, _) {
              final paymentAsync = ref.watch(recurringPaymentByIdProvider(id));
              return paymentAsync.when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => Scaffold(
                  appBar: AppBar(title: const Text('Edit Recurring Payment')),
                  body: Center(child: Text('Failed to load: $err')),
                ),
                data: (payment) => RecurringPaymentFormScreen(
                  existing: payment,
                  onSaved: () => context.pop(),
                  onCancel: () => context.pop(),
                ),
              );
            },
          );
        },
      ),

      // Reports
      GoRoute(
        path: '/reports/financial-summary',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FinancialSummaryScreen(),
      ),
      GoRoute(
        path: '/reports/income',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const IncomeReportScreen(),
      ),
      GoRoute(
        path: '/reports/expense',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExpenseReportScreen(),
      ),
      GoRoute(
        path: '/reports/account',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AccountReportScreen(),
      ),
      GoRoute(
        path: '/reports/money-in-out',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MoneyInOutReportScreen(),
      ),
      GoRoute(
        path: '/reports/daily-balance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DailyBalanceReportScreen(),
      ),
      GoRoute(
        path: '/accounts/:id/statement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccountStatementScreen(
          accountId: int.parse(state.pathParameters['id']!),
        ),
      ),

      // Settings
      GoRoute(
        path: '/settings/account',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            AccountSettingsScreen(onLoggedOut: () => context.go('/welcome')),
      ),
      GoRoute(
        path: '/settings/accounting',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccountingSettingsScreen(
          onManagePeriods: () => context.push('/periods'),
        ),
      ),
      GoRoute(
        path: '/settings/data',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DataSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/security',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/about',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),

      // 5-tab bottom nav shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => DashboardScreen(
                  onAddIncome: () => context.push('/transactions/add-income'),
                  onAddExpense: () => context.push('/transactions/add-expense'),
                  onTransfer: () => context.push('/transfers/new'),
                  onViewTransactions: () => context.go('/transactions'),
                  onReports: () => context.go('/reports'),
                  onViewAccounts: () => context.go('/accounts'),
                  onRecurringPayments: () =>
                      context.push('/recurring-payments'),
                  onTotalAvailableFundsTap: () =>
                      context.push('/reports/account'),
                  onCashFundsTap: () => context.go('/accounts?type=cash'),
                  onOnlineFundsTap: () => context.go('/accounts'),
                  onAccountStatementTap: (accountId) =>
                      context.push('/accounts/$accountId/statement'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) {
                  final accountIdParam = state.uri.queryParameters['accountId'];
                  final typeParam = state.uri.queryParameters['type'];
                  final initialType = switch (typeParam) {
                    'income' => TransactionType.income,
                    'expense' => TransactionType.expense,
                    _ => null,
                  };
                  return TransactionHistoryScreen(
                    initialAccountId: accountIdParam != null
                        ? int.tryParse(accountIdParam)
                        : null,
                    initialType: initialType,
                    onTapTransaction: (entry) =>
                        context.push('/transactions/${entry.id}'),
                    onTapTransfer: (transfer) =>
                        context.push('/transfers/edit/${transfer.id}'),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (context, state) {
                  final typeParam = state.uri.queryParameters['type'];
                  return AccountsListScreen(
                    initialTypeFilter: typeParam != null
                        ? AccountTypeX.fromStorage(typeParam)
                        : null,
                    onTapAccount: (account) =>
                        context.push('/accounts/${account.id}'),
                    onAddAccount: () => context.push('/accounts/new'),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => ReportsHomeScreen(
                  onFinancialSummary: () =>
                      context.push('/reports/financial-summary'),
                  onIncomeReport: () => context.push('/reports/income'),
                  onExpenseReport: () => context.push('/reports/expense'),
                  onAccountReport: () => context.push('/reports/account'),
                  onMoneyInOut: () => context.push('/reports/money-in-out'),
                  onDailyBalance: () => context.push('/reports/daily-balance'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => SettingsHomeScreen(
                  onAccount: () => context.push('/settings/account'),
                  onAccounting: () => context.push('/settings/accounting'),
                  onAccounts: () => context.go('/accounts'),
                  onIncomeCategories: () => context.push('/categories/income'),
                  onExpenseCategories: () =>
                      context.push('/categories/expense'),
                  onData: () => context.push('/settings/data'),
                  onSecurity: () => context.push('/settings/security'),
                  onAppearance: () => context.push('/settings/appearance'),
                  onAbout: () => context.push('/settings/about'),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

Future<void> _showCreatePeriodDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();

  // Default the new period's beginning balance to the previous period's
  // frozen ending balance — leaving this at 0 (the old hardcoded default)
  // silently understated every "Ending Balance" figure computed from this
  // period onward by however much money already existed going in. Falls
  // back to the live sum of account balances when there's no prior closed
  // period to carry forward from (e.g. the very first period).
  final container = ProviderScope.containerOf(context, listen: false);
  final lastClosed = await container
      .read(accountingPeriodDaoProvider)
      .getMostRecentlyClosed();
  double defaultBalance;
  if (lastClosed != null && lastClosed.endingBalance != null) {
    defaultBalance = lastClosed.endingBalance!;
  } else {
    final accounts = await container
        .read(accountDaoProvider)
        .getAll(activeOnly: true);
    defaultBalance = accounts
        .where((a) => a.type.countsTowardAvailableFunds)
        .fold<double>(0, (sum, a) => sum + a.currentBalance);
  }
  final balanceController = TextEditingController(
    text: defaultBalance.toStringAsFixed(2),
  );
  DateTime startDate = DateTime.now();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('New Accounting Period'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Period Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Beginning Balance',
                    ),
                    validator: (v) => double.tryParse((v ?? '').trim()) == null
                        ? 'Enter a valid amount'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                      ),
                      child: Text(
                        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              Consumer(
                builder: (dialogContext, ref, _) {
                  return FilledButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      await ref
                          .read(closePeriodControllerProvider)
                          .openNewPeriod(
                            name: nameController.text.trim(),
                            startDate: startDate,
                            beginningBalance: double.parse(
                              balanceController.text.trim(),
                            ),
                          );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('Create'),
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}

/// The 5-tab bottom navigation shell used by [StatefulShellRoute].
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Adapters that fetch a full domain object for a form screen that needs one
/// (rather than just an id), keeping that concern out of the route builders
/// above.
/// Fills [AccountDetailScreen.transactionsSection] with a real, live list
/// of that account's transactions — this extension point was left
/// unwired during the initial parallel build (each feature agent worked
/// in its own folder and this cross-feature composition step only
/// happens here, at the routing layer). Without this, every account
/// detail page — including e.g. GCash — showed a static "Transactions
/// will appear here." placeholder no matter how many real transactions
/// existed for that account.
class _AccountTransactionsSection extends ConsumerWidget {
  const _AccountTransactionsSection({required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(
      transactionsFilteredProvider(TransactionFilter(accountId: accountId)),
    );
    final accountsAsync = ref.watch(activeAccountsProvider);

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message:
                'Income and expenses recorded on this account will show up here.',
          );
        }
        final sorted = [...entries]
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            if (byDate != 0) return byDate;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });
        final accountName = accountsAsync.maybeWhen(
          data: (accounts) {
            for (final a in accounts) {
              if (a.id == accountId) return a.name;
            }
            return '';
          },
          orElse: () => '',
        );
        return Column(
          children: [
            ...sorted
                .take(15)
                .map(
                  (e) => TransactionTile(
                    entryType: e.isIncome
                        ? HistoryEntryType.income
                        : HistoryEntryType.expense,
                    title: (e.description == null || e.description!.isEmpty)
                        ? (e.isIncome ? 'Income' : 'Expense')
                        : e.description!,
                    date: e.date,
                    amount: e.amount,
                    accountName: accountName,
                    onTap: () => context.push('/transactions/${e.id}'),
                  ),
                ),
            if (sorted.length > 15)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TextButton(
                  onPressed: () =>
                      context.push('/transactions?accountId=$accountId'),
                  child: const Text('View All Transactions'),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Text('Failed to load transactions: $err'),
    );
  }
}

class _AccountEditRoute extends ConsumerWidget {
  const _AccountEditRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(id));
    return accountAsync.when(
      data: (account) {
        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Account')),
            body: const Center(child: Text('Account not found.')),
          );
        }
        return AccountFormScreen(
          existing: account,
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('Failed to load account: $err'))),
    );
  }
}

class _TransactionEditRoute extends ConsumerWidget {
  const _TransactionEditRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(transactionByIdProvider(id));
    return entryAsync.when(
      data: (entry) {
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Transaction')),
            body: const Center(child: Text('Transaction not found.')),
          );
        }
        return entry.isIncome
            ? IncomeEntryScreen(
                editing: entry,
                onSaved: () => context.pop(),
                onCancel: () => context.pop(),
              )
            : ExpenseEntryScreen(
                editing: entry,
                onSaved: () => context.pop(),
                onCancel: () => context.pop(),
              );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(
        body: Center(child: Text('Failed to load transaction: $err')),
      ),
    );
  }
}

class _TransferEditRoute extends ConsumerWidget {
  const _TransferEditRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferAsync = ref.watch(transferByIdProvider(id));
    return transferAsync.when(
      data: (transfer) {
        if (transfer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Transfer')),
            body: const Center(child: Text('Transfer not found.')),
          );
        }
        return TransferMoneyScreen(
          editing: transfer,
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('Failed to load transfer: $err'))),
    );
  }
}

class _CategoryEditRoute extends ConsumerWidget {
  const _CategoryEditRoute({required this.isIncome, required this.id});

  final bool isIncome;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isIncome) {
      final categoriesAsync = ref.watch(incomeCategoriesStreamProvider);
      return categoriesAsync.when(
        data: (categories) {
          final matches = categories.where((c) => c.id == id);
          final existing = matches.isEmpty ? null : matches.first;
          return CategoryFormScreen(
            isIncome: true,
            existing: existing,
            onSaved: () => context.pop(),
            onCancel: () => context.pop(),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, st) => Scaffold(
          body: Center(child: Text('Failed to load category: $err')),
        ),
      );
    }

    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    return categoriesAsync.when(
      data: (categories) {
        final matches = categories.where((c) => c.id == id);
        final existing = matches.isEmpty ? null : matches.first;
        return CategoryFormScreen(
          isIncome: false,
          existing: existing,
          onSaved: () => context.pop(),
          onCancel: () => context.pop(),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) =>
          Scaffold(body: Center(child: Text('Failed to load category: $err'))),
    );
  }
}
