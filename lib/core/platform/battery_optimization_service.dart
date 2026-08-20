import 'dart:io';

import 'package:flutter/services.dart';

/// Wraps the native Android channel (see MainActivity.kt) that lets
/// MiarhPen ask, in-app, to be exempted from battery optimization /
/// background-process freezing. Several OEM Android skins (Honor's Magic
/// OS in particular) aggressively suspend newly-installed apps that
/// aren't on this exemption list, which can make the app appear
/// unresponsive to taps even though nothing is actually wrong with it.
/// Rather than asking the user to go find this in Settings themselves,
/// the app requests it directly — no manual configuration required.
class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel(
    'com.emfitsolutions.miarhpen/battery_optimization',
  );

  /// Only meaningful on Android; always true elsewhere (nothing to ask).
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Shows the system "Allow MiarhPen to ignore battery optimizations?"
  /// dialog. No-ops on non-Android platforms and if already exempted.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on PlatformException {
      // Nothing meaningful to recover to — worst case the user stays on
      // the default (optimized) behavior, which is not a functional
      // failure, just a possible responsiveness one on some OEM skins.
    }
  }
}
