import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'update_checker_service.dart';

/// Downloads a newer release's APK in the background and hands it
/// straight to Android's package installer — no browser tab, no "tap
/// this link to download" step of MiarhPen's own. This is as silent as
/// Android allows: the OS still shows its own one-tap "Install app?"
/// confirmation before the update actually installs, which cannot be
/// skipped without device-owner/root privileges (this app deliberately
/// doesn't request either).
class AppUpdaterService {
  static const MethodChannel _channel = MethodChannel(
    'com.emfitsolutions.miarhpen/apk_installer',
  );

  /// No-ops (returns false) on anything other than Android, or if
  /// [UpdateInfo.apkDownloadUrl] is missing, or if the download/handoff
  /// fails for any reason — silent update delivery must never be able to
  /// crash or interrupt the app it's trying to update.
  Future<bool> downloadAndInstall(UpdateInfo info) async {
    if (!Platform.isAndroid) return false;
    final url = info.apkDownloadUrl;
    if (url == null) return false;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) return false;

      final dir = await getTemporaryDirectory();
      // A fixed filename (not one keyed by version) so a half-downloaded
      // or previous update doesn't pile up extra copies in the cache —
      // each new download just overwrites the last one.
      final file = File('${dir.path}/miarhpen-update.apk');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      await _channel.invokeMethod<void>('installApk', {'path': file.path});
      return true;
    } catch (_) {
      return false;
    }
  }
}
