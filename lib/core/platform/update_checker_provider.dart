import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_checker_service.dart';

final updateCheckerServiceProvider = Provider<UpdateCheckerService>(
  (ref) => UpdateCheckerService(),
);

/// Null when there is no update (including every failure case — see
/// [UpdateCheckerService.checkForUpdate]), or an [UpdateInfo] describing
/// what's newer and where to get it. Checked once per app session
/// (autoDispose: re-checks fresh next time this provider is watched again
/// after being torn down, e.g. after fully restarting the app).
final updateCheckProvider = FutureProvider.autoDispose<UpdateInfo?>((ref) {
  return ref.watch(updateCheckerServiceProvider).checkForUpdate();
});
