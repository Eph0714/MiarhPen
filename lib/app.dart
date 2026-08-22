import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/battery_optimization_service.dart';
import 'core/routing/app_router.dart';
import 'core/security/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/application/auth_provider.dart';
import 'features/categories/application/seed_default_categories.dart';
import 'features/recurring_payments/application/reschedule_recurring_payment_alarms.dart';
import 'features/transactions/application/backfill_transaction_periods.dart';
import 'features/transactions/application/reassign_debit_card_transactions.dart';

/// Root widget: builds the go_router-based app shell, seeds default
/// categories on first launch, and resets the idle/session timer on any
/// user interaction anywhere in the app.
class MiarhPenApp extends ConsumerStatefulWidget {
  const MiarhPenApp({super.key});

  @override
  ConsumerState<MiarhPenApp> createState() => _MiarhPenAppState();
}

class _MiarhPenAppState extends ConsumerState<MiarhPenApp> {
  final _batteryOptimizationService = BatteryOptimizationService();
  final _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    // All idempotent — safe to fire-and-forget on every app start.
    seedDefaultCategoriesIfNeeded();
    backfillTransactionPeriodsIfNeeded();
    rescheduleRecurringPaymentAlarmsIfNeeded();
    reassignDebitCardTransactionsIfNeeded();
  }

  /// Asks, once ever, for exemption from battery optimization /
  /// background-process freezing — some OEM Android skins (Honor's Magic
  /// OS in particular) aggressively suspend newly-installed apps, which
  /// can make the app appear to silently ignore taps even though nothing
  /// is functionally wrong. This is handled entirely in-app (one system
  /// permission dialog) so the user never has to hunt through Settings
  /// themselves.
  Future<void> _maybePromptBatteryOptimization() async {
    final alreadyPrompted = await _secureStorage.read(
      SecureStorageService.batteryOptimizationPrompted,
    );
    if (alreadyPrompted == 'true') return;

    final alreadyExempt = await _batteryOptimizationService
        .isIgnoringBatteryOptimizations();
    if (!alreadyExempt) {
      await _batteryOptimizationService.requestIgnoreBatteryOptimizations();
    }
    await _secureStorage.write(
      SecureStorageService.batteryOptimizationPrompted,
      'true',
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final sessionManager = ref.watch(sessionManagerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        // Fire after the current frame/navigation settles rather than
        // mid-transition.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybePromptBatteryOptimization();
        });
      }
    });

    return Listener(
      onPointerDown: (_) => sessionManager.recordActivity(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp.router(
        title: 'MiarhPen',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        // AppColors.x is a bunch of runtime getters (not fixed constants)
        // so every custom widget/painter that reads it — outside of what
        // ThemeData already drives automatically — follows whichever
        // theme actually got resolved here, including ThemeMode.system
        // resolving against the platform's brightness. This is the one
        // place that syncs the two: it runs once per rebuild, always
        // with the real resolved Theme available.
        builder: (context, child) {
          AppColors.setBrightness(Theme.of(context).brightness);
          return child!;
        },
        routerConfig: router,
      ),
    );
  }
}
