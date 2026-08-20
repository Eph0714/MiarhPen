import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Tracks user idle time and locks the app after [timeout] of inactivity.
///
/// The root widget/router should wire a top-level `Listener` (or similar
/// pointer-event hook) to call [recordActivity] on any tap/scroll, so the
/// idle timer resets without locking the app.
class SessionManager extends ChangeNotifier {
  SessionManager({Duration? timeout})
      : timeout = timeout ??
            const Duration(
              minutes: AppConstants.defaultSessionTimeoutMinutes,
            );

  Duration timeout;

  Timer? _timer;
  bool _locked = false;

  bool get isLocked => _locked;

  void start() {
    _timer?.cancel();
    _timer = Timer(timeout, () {
      _locked = true;
      notifyListeners();
    });
  }

  void recordActivity() {
    if (_locked) return;
    _timer?.cancel();
    _timer = Timer(timeout, () {
      _locked = true;
      notifyListeners();
    });
  }

  void lockNow() {
    _timer?.cancel();
    _locked = true;
    notifyListeners();
  }

  void unlock() {
    _locked = false;
    start();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
