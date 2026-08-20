import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/expense_category_dao.dart';
import '../../../core/db/daos/income_category_dao.dart';
import '../../../core/db/db_change_notifier.dart';
import '../../../core/security/password_hasher.dart';
import '../../accounting_periods/domain/accounting_period.dart';
import '../../accounts/domain/account.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user.dart';

/// A single "initial account" row collected on the setup wizard's
/// beginning-balance step.
class InitialAccountDraft {
  final String name;
  final AccountType type;
  final double beginningBalance;

  const InitialAccountDraft({
    required this.name,
    required this.type,
    required this.beginningBalance,
  });

  InitialAccountDraft copyWith({
    String? name,
    AccountType? type,
    double? beginningBalance,
  }) {
    return InitialAccountDraft(
      name: name ?? this.name,
      type: type ?? this.type,
      beginningBalance: beginningBalance ?? this.beginningBalance,
    );
  }
}

class SetupWizardState {
  final int step;

  final String username;
  final String password;
  final String confirmPassword;

  final String currencyCode;
  final String currencySymbol;

  final String periodName;
  final DateTime periodStartDate;

  final List<InitialAccountDraft> initialAccounts;

  final bool isSubmitting;
  final String? errorText;

  const SetupWizardState({
    this.step = 0,
    this.username = '',
    this.password = '',
    this.confirmPassword = '',
    this.currencyCode = AppConstants.defaultCurrencyCode,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    required this.periodName,
    required this.periodStartDate,
    this.initialAccounts = const [],
    this.isSubmitting = false,
    this.errorText,
  });

  double get beginningBalanceTotal =>
      initialAccounts.fold(0.0, (sum, a) => sum + a.beginningBalance);

  SetupWizardState copyWith({
    int? step,
    String? username,
    String? password,
    String? confirmPassword,
    String? currencyCode,
    String? currencySymbol,
    String? periodName,
    DateTime? periodStartDate,
    List<InitialAccountDraft>? initialAccounts,
    bool? isSubmitting,
    String? errorText,
    bool clearError = false,
  }) {
    return SetupWizardState(
      step: step ?? this.step,
      username: username ?? this.username,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      periodName: periodName ?? this.periodName,
      periodStartDate: periodStartDate ?? this.periodStartDate,
      initialAccounts: initialAccounts ?? this.initialAccounts,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorText: clearError ? null : (errorText ?? this.errorText),
    );
  }
}

class SetupWizardController extends Notifier<SetupWizardState> {
  @override
  SetupWizardState build() {
    final now = DateTime.now();
    final monthName = _monthName(now.month);
    return SetupWizardState(
      periodName: '$monthName ${now.year}',
      periodStartDate: DateTime(now.year, now.month, now.day),
    );
  }

  static String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  void goToStep(int step) {
    state = state.copyWith(step: step, clearError: true);
  }

  void nextStep() {
    state = state.copyWith(step: state.step + 1, clearError: true);
  }

  void previousStep() {
    if (state.step == 0) return;
    state = state.copyWith(step: state.step - 1, clearError: true);
  }

  void setCredentials({
    String? username,
    String? password,
    String? confirmPassword,
  }) {
    state = state.copyWith(
      username: username,
      password: password,
      confirmPassword: confirmPassword,
      clearError: true,
    );
  }

  void setCurrency(String currencyCode, String currencySymbol) {
    state = state.copyWith(
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      clearError: true,
    );
  }

  void setPeriod({String? periodName, DateTime? periodStartDate}) {
    state = state.copyWith(
      periodName: periodName,
      periodStartDate: periodStartDate,
      clearError: true,
    );
  }

  void addInitialAccount(InitialAccountDraft draft) {
    state = state.copyWith(
      initialAccounts: [...state.initialAccounts, draft],
      clearError: true,
    );
  }

  void removeInitialAccount(int index) {
    final updated = [...state.initialAccounts]..removeAt(index);
    state = state.copyWith(initialAccounts: updated, clearError: true);
  }

  void updateInitialAccount(int index, InitialAccountDraft draft) {
    final updated = [...state.initialAccounts];
    updated[index] = draft;
    state = state.copyWith(initialAccounts: updated, clearError: true);
  }

  Future<void> completeSetup() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final now = DateTime.now();
      final passwordHash = PasswordHasher.hash(state.password);
      final userDao = ref.read(userDaoProvider);

      // Defense in depth: if a user with this username already exists —
      // e.g. a previous "Finish Setup" tap's transaction (below) committed
      // successfully but a later, non-transactional step (category
      // seeding, auto-login) then threw, leaving the wizard stuck on this
      // screen — re-running the insert would fail on the UNIQUE username
      // constraint even though setup already substantively completed.
      // Detect that case and skip straight to the post-transaction steps
      // using the already-created user, instead of erroring forever.
      final existingUser = await userDao.getByUsername(state.username.trim());

      // Steps 1-3 (user, initial accounts, first accounting period) run
      // inside a single database transaction so they either all commit or
      // none do. Without this, a failure partway through (e.g. after the
      // user row was created but before the accounts/period were) leaves
      // an orphaned user row behind; retrying "Finish Setup" then fails
      // immediately with a UNIQUE constraint error on username, since that
      // row already exists but the wizard has no way to know setup didn't
      // actually finish. Wrapping the whole sequence atomically means any
      // failure rolls back cleanly and a retry starts from a clean slate.
      final db = await AppDatabase.instance.database;
      final userId = existingUser?.id ?? await db.transaction<int>((txn) async {
        final insertedUserId = await txn.insert(
          'users',
          AppUser(
            username: state.username.trim(),
            passwordHash: passwordHash,
            sessionTimeoutMin: AppConstants.defaultSessionTimeoutMinutes,
            currencyCode: state.currencyCode,
            currencySymbol: state.currencySymbol,
            createdAt: now,
            updatedAt: now,
          ).toMap(),
        );

        for (final draft in state.initialAccounts) {
          await txn.insert(
            'accounts',
            Account(
              name: draft.name,
              type: draft.type,
              beginningBalance: draft.beginningBalance,
              currentBalance: draft.beginningBalance,
              outstandingBalance:
                  draft.type == AccountType.creditCard ? 0 : null,
              createdAt: now,
              updatedAt: now,
            ).toMap(),
          );
        }

        await txn.insert(
          'accounting_periods',
          AccountingPeriod(
            name: state.periodName,
            startDate: state.periodStartDate,
            beginningBalance: state.beginningBalanceTotal,
            createdAt: now,
          ).toMap(),
        );

        return insertedUserId;
      });

      DbChangeNotifier.instance.notifyAll(const [
        DbTable.users,
        DbTable.accounts,
        DbTable.accountingPeriods,
      ]);

      // Seed default categories (idempotent — skips names that already
      // exist — so it's safe outside the transaction above and safe to
      // call again on a retry).
      // NOTE: `seedDefaultCategoriesIfNeeded()` from
      // `lib/features/categories/application/seed_default_categories.dart`
      // was not present at the time this feature was built, so the DAOs
      // are called directly as a fallback. If that file exists now,
      // consider de-duplicating this call.
      await IncomeCategoryDao().seedDefaults(DefaultCategories.income);
      await ExpenseCategoryDao().seedDefaults(DefaultCategories.expense);

      // Log the freshly-created (or already-existing, on a retry) user
      // straight in.
      final createdUser = existingUser ?? await userDao.getById(userId);

      // CRITICAL: invalidate the cached "does a user exist yet" read
      // before setting auth state / navigating away. The router's
      // redirect logic checks this provider on every navigation; if it's
      // left holding its stale pre-onboarding value (no user), it
      // immediately bounces any post-setup navigation straight back to
      // /onboarding — completeSetup() has *already succeeded* at that
      // point (the account is really created), but the UI looks exactly
      // like "Finish Setup" silently did nothing. This was the actual
      // root cause of that bug — see MEMORY/plan notes.
      ref.invalidate(currentUserProvider);

      if (createdUser != null) {
        ref.read(authControllerProvider.notifier).state =
            AuthState.loggedIn(createdUser);
      }

      state = state.copyWith(isSubmitting: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorText: e.toString());
      rethrow;
    }
  }
}

final setupWizardControllerProvider =
    NotifierProvider<SetupWizardController, SetupWizardState>(
  SetupWizardController.new,
);
