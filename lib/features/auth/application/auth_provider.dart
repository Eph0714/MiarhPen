import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/db/daos/user_dao.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/password_hasher.dart';
import '../../../core/security/pin_service.dart';
import '../../../core/security/session_manager.dart';
import '../domain/user.dart';

final userDaoProvider = Provider<UserDao>((ref) => UserDao());

final currentUserProvider = FutureProvider<AppUser?>((ref) {
  return ref.watch(userDaoProvider).getFirstUser();
});

/// The one user (if any) currently flagged for "Remember Me" auto-login.
/// Read directly by the router's redirect logic (not just by
/// [AuthController]'s own best-effort background attempt) so a
/// remembered session is restored deterministically on cold start,
/// without depending on a detached microtask racing the router's first
/// redirect evaluation.
final rememberedUserProvider = FutureProvider<AppUser?>((ref) {
  return ref.watch(userDaoProvider).getRememberedUser();
});

/// Kept alive app-wide — session state must persist regardless of which
/// screens are currently mounted/watching it.
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager()..start();
  ref.onDispose(manager.dispose);
  return manager;
});

final pinServiceProvider = Provider<PinService>((ref) => PinService());

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

enum AuthStatus { loggedOut, loggedIn, locked }

class AuthState {
  final AuthStatus status;
  final AppUser? user;

  const AuthState._(this.status, this.user);

  const AuthState.loggedOut() : this._(AuthStatus.loggedOut, null);

  const AuthState.loggedIn(AppUser user) : this._(AuthStatus.loggedIn, user);

  const AuthState.locked(AppUser user) : this._(AuthStatus.locked, user);

  bool get isLoggedOut => status == AuthStatus.loggedOut;
  bool get isLoggedIn => status == AuthStatus.loggedIn;
  bool get isLocked => status == AuthStatus.locked;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Listen for session timeouts and flip a logged-in session to locked.
    final sessionManager = ref.watch(sessionManagerProvider);
    sessionManager.addListener(_onSessionChanged);
    ref.onDispose(() => sessionManager.removeListener(_onSessionChanged));

    // "Remember Me" auto-login: Notifier.build() must return synchronously,
    // so the actual DB lookup happens in the background and flips `state`
    // once it resolves (briefly showing the Welcome/Login screen first on
    // a remembered session is an acceptable tradeoff for not rewriting
    // this controller as an AsyncNotifier, which every `ref.read
    // (authControllerProvider)` call site — the router's redirect logic
    // especially — assumes returns a plain [AuthState] synchronously).
    Future.microtask(_tryAutoLogin);

    return const AuthState.loggedOut();
  }

  Future<void> _tryAutoLogin() async {
    if (!state.isLoggedOut) return; // already logged in/locked somehow
    final remembered = await ref.read(userDaoProvider).getRememberedUser();
    if (remembered == null || !state.isLoggedOut) return;
    applyRememberedUser(remembered);
  }

  /// Restores a "Remember Me" session. Idempotent/safe to call more than
  /// once (e.g. from both this controller's own background attempt and
  /// the router's redirect logic, whichever notices first) — a no-op if
  /// the app is already past the logged-out state by the time it runs.
  void applyRememberedUser(AppUser user) {
    if (!state.isLoggedOut) return;
    state = AuthState.loggedIn(user);
    ref.read(sessionManagerProvider).unlock();
  }

  void _onSessionChanged() {
    final sessionManager = ref.read(sessionManagerProvider);
    if (sessionManager.isLocked && state.isLoggedIn && state.user != null) {
      lock();
    }
  }

  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final userDao = ref.read(userDaoProvider);
    final user = await userDao.getByUsername(username);
    if (user == null) return false;
    if (!PasswordHasher.verify(password, user.passwordHash)) return false;

    // Only one remembered session makes sense per device — clear anyone
    // else's flag before setting this one.
    if (rememberMe) {
      await userDao.clearAllRememberMe();
    }
    final updated = user.copyWith(rememberMe: rememberMe);
    await userDao.update(updated);

    state = AuthState.loggedIn(updated);
    ref.read(sessionManagerProvider).unlock();
    return true;
  }

  /// Creates an additional user who shares the same accounts,
  /// transactions, categories, and periods as everyone else — MiarhPen
  /// is a shared-household/team ledger, not per-user isolated data.
  /// Only the login credentials (and personal preferences like PIN/
  /// biometric) are unique to each user. Returns null on success, or a
  /// user-facing error message on failure.
  Future<String?> signUp(String username, String password) async {
    final trimmedUsername = username.trim();
    final userDao = ref.read(userDaoProvider);

    final existing = await userDao.getByUsername(trimmedUsername);
    if (existing != null) return 'That username is already taken.';

    // Inherit shared settings (currency, session timeout) from whoever
    // set the app up first, since these apply to the whole household/
    // team, not to one person.
    final firstUser = await userDao.getFirstUser();
    final now = DateTime.now();
    final newUser = AppUser(
      username: trimmedUsername,
      passwordHash: PasswordHasher.hash(password),
      sessionTimeoutMin:
          firstUser?.sessionTimeoutMin ??
          AppConstants.defaultSessionTimeoutMinutes,
      currencyCode: firstUser?.currencyCode ?? AppConstants.defaultCurrencyCode,
      currencySymbol:
          firstUser?.currencySymbol ?? AppConstants.defaultCurrencySymbol,
      createdAt: now,
      updatedAt: now,
    );

    final id = await userDao.insert(newUser);
    final created = await userDao.getById(id);
    if (created == null) return 'Something went wrong creating your account.';

    state = AuthState.loggedIn(created);
    ref.read(sessionManagerProvider).unlock();
    return null;
  }

  Future<void> logout() async {
    // An explicit logout always requires logging in again next time, even
    // if "Remember Me" was checked — otherwise the app would just log the
    // user straight back in on the next launch, which isn't what anyone
    // tapping Logout expects.
    final user = state.user;
    if (user != null && user.rememberMe) {
      await ref.read(userDaoProvider).clearAllRememberMe();
    }
    state = const AuthState.loggedOut();
  }

  void lock() {
    final user = state.user;
    if (user == null) return;
    state = AuthState.locked(user);
  }

  Future<bool> unlockWithPassword(String password) async {
    final user = state.user;
    if (user == null) return false;
    if (!PasswordHasher.verify(password, user.passwordHash)) return false;
    state = AuthState.loggedIn(user);
    ref.read(sessionManagerProvider).unlock();
    return true;
  }

  Future<bool> unlockWithPin(String pin) async {
    final user = state.user;
    if (user == null || user.pinHash == null) return false;
    final pinService = ref.read(pinServiceProvider);
    if (!PinService.verifyPin(pin, user.pinHash!)) {
      await pinService.recordFailedAttempt();
      return false;
    }
    await pinService.resetFailedAttempts();
    state = AuthState.loggedIn(user);
    ref.read(sessionManagerProvider).unlock();
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    final user = state.user;
    if (user == null) return false;
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(reason: 'Unlock MiarhPen');
    if (!ok) return false;
    state = AuthState.loggedIn(user);
    ref.read(sessionManagerProvider).unlock();
    return true;
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = state.user;
    if (user == null) return;
    if (!PasswordHasher.verify(currentPassword, user.passwordHash)) {
      throw Exception('Current password is incorrect');
    }
    final newHash = PasswordHasher.hash(newPassword);
    final userDao = ref.read(userDaoProvider);
    await userDao.updatePassword(user.id!, newHash, user.passwordSalt);
    final updated = user.copyWith(passwordHash: newHash);
    state = AuthState.loggedIn(updated);
  }

  Future<void> setupPin(String pin) async {
    final user = state.user;
    if (user == null) return;
    final hash = PinService.hashPin(pin);
    final userDao = ref.read(userDaoProvider);
    await userDao.updatePin(user.id!, hash);
    final updated = user.copyWith(pinHash: hash);
    state = AuthState.loggedIn(updated);
  }

  Future<void> disablePin() async {
    final user = state.user;
    if (user == null) return;
    final userDao = ref.read(userDaoProvider);
    await userDao.updatePin(user.id!, null);
    // AppUser.copyWith() cannot null out pinHash (it uses `??`), so
    // reconstruct explicitly.
    final updated = AppUser(
      id: user.id,
      username: user.username,
      passwordHash: user.passwordHash,
      passwordSalt: user.passwordSalt,
      pinHash: null,
      biometricEnabled: user.biometricEnabled,
      rememberMe: user.rememberMe,
      sessionTimeoutMin: user.sessionTimeoutMin,
      currencyCode: user.currencyCode,
      currencySymbol: user.currencySymbol,
      createdAt: user.createdAt,
      updatedAt: DateTime.now(),
    );
    state = AuthState.loggedIn(updated);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final user = state.user;
    if (user == null) return;
    final userDao = ref.read(userDaoProvider);
    await userDao.updateBiometricEnabled(user.id!, enabled);
    final updated = user.copyWith(biometricEnabled: enabled);
    state = AuthState.loggedIn(updated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
