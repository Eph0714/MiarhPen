import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_provider.dart';

/// Bridges Riverpod state changes into a [Listenable] go_router can use as
/// its `refreshListenable`, so the router re-evaluates `redirect` whenever
/// auth status (logged out / logged in / locked, including the one-time
/// `autoLoginChecked` flip — see [AuthState]) or the current-user lookup
/// changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _authSub = _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: false,
    );
    _userSub = _ref.listen<AsyncValue<dynamic>>(
      currentUserProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _authSub;
  late final ProviderSubscription<AsyncValue<dynamic>> _userSub;

  @override
  void dispose() {
    _authSub.close();
    _userSub.close();
    super.dispose();
  }
}
