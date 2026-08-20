import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/widgets/app_card.dart';

/// Settings > Appearance: lets the user pick Light, Dark, or System
/// Default for the whole app's theme. The choice is persisted (see
/// [ThemeModeController]) and takes effect immediately — no restart
/// needed.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Select Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ThemeOption(
                  icon: Icons.brightness_auto_outlined,
                  label: 'System Default',
                  subtitle: 'Follows your device\'s setting',
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (mode) => ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(mode),
                ),
                const Divider(height: 1),
                _ThemeOption(
                  icon: Icons.light_mode_outlined,
                  label: 'Light',
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (mode) => ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(mode),
                ),
                const Divider(height: 1),
                _ThemeOption(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark',
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (mode) => ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(mode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
      },
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
    );
  }
}
