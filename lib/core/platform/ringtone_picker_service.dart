import 'dart:io';

import 'package:flutter/services.dart';

/// One picked system sound: its content URI (stored/played back later) and
/// a human-readable display name (shown in the UI instead of the URI).
class PickedRingtone {
  final String uri;
  final String name;

  const PickedRingtone({required this.uri, required this.name});
}

/// Wraps the native Android channel (see MainActivity.kt) that opens the
/// system's own sound picker (`RingtoneManager.ACTION_RINGTONE_PICKER`),
/// scoped to the phone's Alarm sounds — this is what lets a Recurring
/// Payment's reminder play any alarm sound already installed on the
/// device, rather than the app shipping/bundling its own fixed sound.
class RingtonePickerService {
  static const MethodChannel _channel = MethodChannel(
    'com.emfitsolutions.miarhpen/ringtone_picker',
  );

  /// Only meaningful on Android; returns null immediately elsewhere.
  ///
  /// [existingUri] pre-selects the currently-chosen sound in the picker
  /// dialog, if any. Returns null if the user cancels the picker or picks
  /// "Silent".
  Future<PickedRingtone?> pickAlarmSound({String? existingUri}) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'pickAlarmSound',
        {'existingUri': existingUri},
      );
      if (result == null) return null;
      final uri = result['uri'] as String?;
      final name = result['name'] as String?;
      if (uri == null) return null;
      return PickedRingtone(uri: uri, name: name ?? 'Selected sound');
    } on PlatformException {
      return null;
    }
  }
}
