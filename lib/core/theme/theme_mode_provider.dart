import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

String _themeModeToStorage(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

ThemeMode _themeModeFromStorage(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// The user's chosen theme (Settings > Appearance > Select Theme),
/// persisted across launches. Defaults to [ThemeMode.system] the first
/// time the app runs, before any explicit choice has been made.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Notifier.build() must return synchronously, so the persisted value
    // is loaded in the background and applied once it resolves — same
    // pattern as AuthController's "Remember Me" restore. Defaulting to
    // system in the meantime is a safe, unsurprising placeholder either
    // way.
    Future.microtask(_loadPersisted);
    return ThemeMode.system;
  }

  Future<void> _loadPersisted() async {
    final stored = await ref
        .read(secureStorageProvider)
        .read(SecureStorageService.themeMode);
    if (stored == null) return;
    state = _themeModeFromStorage(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(secureStorageProvider)
        .write(SecureStorageService.themeMode, _themeModeToStorage(mode));
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
