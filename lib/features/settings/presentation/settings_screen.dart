import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/utils/app_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../shared/widgets/tv_input_widgets.dart';

import 'widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';
import 'player_settings_provider.dart';
import '../../../core/services/external_player_service.dart';
import '../../../core/network/doh_service.dart';

// Simple provider for app version
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} +${info.buildNumber}';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final themeMode = ref.watch(themeModeProvider);

    final playerSettings = ref.watch(playerSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SizedBox(height: 8),
              SettingsGroup(
                title: 'General',
                children: [
                  SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'App Theme',
                    subtitle: themeMode == ThemeMode.system
                        ? 'System'
                        : (themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
                    isLast: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          surfaceTintColor: Colors.transparent,
                          title: const Text('Choose Theme'),
                          content: RadioGroup<ThemeMode>(
                            groupValue: themeMode,
                            onChanged: (val) {
                              if (val == null) return;
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(val);
                              Navigator.pop(context);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _themeOption('System', ThemeMode.system),
                                _themeOption('Dark', ThemeMode.dark),
                                _themeOption('Light', ThemeMode.light),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsGroup(
                title: 'Player',
                children: [
                  SettingsTile(
                    icon: Icons.smart_display_rounded,
                    title: 'Default Player',
                    subtitle: _getPlayerDisplayName(
                      playerSettings.preferredPlayer,
                    ),
                    onTap: () => _showDefaultPlayerDialog(
                      context,
                      ref,
                      playerSettings.preferredPlayer,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.swipe_vertical_rounded,
                    title: 'Left Gesture',
                    subtitle:
                        playerSettings.leftGesture.name[0].toUpperCase() +
                        playerSettings.leftGesture.name.substring(1),
                    onTap: () => _showGestureDialog(
                      context,
                      ref,
                      true,
                      playerSettings.leftGesture,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.swipe_vertical_rounded,
                    title: 'Right Gesture',
                    subtitle:
                        playerSettings.rightGesture.name[0].toUpperCase() +
                        playerSettings.rightGesture.name.substring(1),
                    onTap: () => _showGestureDialog(
                      context,
                      ref,
                      false,
                      playerSettings.rightGesture,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.touch_app_rounded,
                    title: 'Double Tap to Seek',
                    subtitle: playerSettings.doubleTapEnabled
                        ? 'Enabled'
                        : 'Disabled',
                    trailing: Switch(
                      value: playerSettings.doubleTapEnabled,
                      onChanged: (val) => ref
                          .read(playerSettingsProvider.notifier)
                          .setDoubleTapEnabled(val),
                    ),
                    onTap: () => ref
                        .read(playerSettingsProvider.notifier)
                        .setDoubleTapEnabled(!playerSettings.doubleTapEnabled),
                  ),
                  SettingsTile(
                    icon: Icons.swipe_rounded,
                    title: 'Swipe to Seek',
                    subtitle: playerSettings.swipeSeekEnabled
                        ? 'Enabled'
                        : 'Disabled',
                    trailing: Switch(
                      value: playerSettings.swipeSeekEnabled,
                      onChanged: (val) => ref
                          .read(playerSettingsProvider.notifier)
                          .setSwipeSeekEnabled(val),
                    ),
                    onTap: () => ref
                        .read(playerSettingsProvider.notifier)
                        .setSwipeSeekEnabled(!playerSettings.swipeSeekEnabled),
                  ),
                  SettingsTile(
                    icon: Icons.av_timer_rounded,
                    title: 'Seek Duration',
                    subtitle: _formatSeekDuration(playerSettings.seekDuration),
                    onTap: () => _showDurationDialog(
                      context,
                      ref,
                      playerSettings.seekDuration,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.aspect_ratio_rounded,
                    title: 'Default Resize Mode',
                    subtitle: playerSettings.defaultResizeMode,
                    onTap: () => _showResizeDialog(
                      context,
                      ref,
                      playerSettings.defaultResizeMode,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.subtitles_rounded,
                    title: 'Subtitles',
                    subtitle: 'Customize appearance',
                    isLast: true,
                    onTap: () =>
                        _showSubtitleDialog(context, ref, playerSettings),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: DohService.instance,
                builder: (context, _) => SettingsGroup(
                  title: 'Network',
                  children: [
                    SettingsTile(
                      icon: Icons.dns_rounded,
                      title: 'DNS over HTTPS',
                      subtitle: DohService.instance.enabled
                          ? 'On (${_getDohProviderLabel(DohService.instance.provider, DohService.instance.customUrl)})'
                          : 'Off',
                      trailing: Switch(
                        value: DohService.instance.enabled,
                        onChanged: (val) {
                          DohService.instance.setEnabled(val);
                        },
                      ),
                      onTap: () {
                        DohService.instance.setEnabled(
                          !DohService.instance.enabled,
                        );
                      },
                    ),
                    if (DohService.instance.enabled)
                      SettingsTile(
                        icon: Icons.cloud_rounded,
                        title: 'DoH Provider',
                        subtitle: _getDohProviderLabel(
                          DohService.instance.provider,
                          DohService.instance.customUrl,
                        ),
                        isLast: true,
                        onTap: () => _showDohProviderDialog(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SettingsGroup(
                title: 'Extensions',
                children: [
                  SettingsTile(
                    icon: Icons.extension_rounded,
                    title: 'Manage Extensions',
                    subtitle: 'Install or remove providers',
                    isLast: true,
                    onTap: () => context.go('/settings/extensions'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsGroup(
                title: 'App Data',
                children: [
                  SettingsTile(
                    icon: Icons.restore_rounded,
                    title: 'Reset Data (Keep Extensions)',
                    subtitle: 'Clear settings & database, keep plugin',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          surfaceTintColor: Colors.transparent,
                          title: const Text('Reset Data?'),
                          content: const Text(
                            'This will clear Settings, Favorites, and History. Your installed Extensions will be SAVED.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);

                                // Clear Preferences ONLY
                                await ref
                                    .read(storageServiceProvider)
                                    .clearPreferences();

                                // Restart App
                                if (context.mounted)
                                  await AppUtils.restartApp(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                              ),
                              child: const Text('Reset Data'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Factory Reset',
                    subtitle: 'Delete all data, settings, and extensions',
                    isLast: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          surfaceTintColor: Colors.transparent,
                          title: const Text('Factory Reset?'),
                          content: const Text(
                            'This will delete EVERYTHING: Favorites, History, Settings, and ALL Extensions. This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                // Deep Clean (Extensions, Prefs, Hive)
                                await ref
                                    .read(storageServiceProvider)
                                    .deleteAllData();

                                // Restart App
                                if (context.mounted)
                                  await AppUtils.restartApp(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Factory Reset'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsGroup(
                title: 'Developer',
                children: [
                  SettingsTile(
                    icon: Icons.developer_mode_rounded,
                    title: 'Developer Options',
                    subtitle: 'Debug tools & local play',
                    isLast: true,
                    onTap: () => context.go('/settings/developer'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SettingsGroup(
                title: 'About',
                children: [
                  SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: versionAsync.when(
                      data: (v) => v,
                      loading: () => 'Loading...',
                      error: (err, stack) => 'Unknown',
                    ),
                    trailing: const SizedBox.shrink(),
                    isLast: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(String title, ThemeMode value) {
    return RadioListTile<ThemeMode>(title: Text(title), value: value);
  }

  void _showGestureDialog(
    BuildContext context,
    WidgetRef ref,
    bool isLeft,
    PlayerGesture current,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text('Select ${isLeft ? "Left" : "Right"} Gesture'),
        content: RadioGroup<PlayerGesture>(
          groupValue: current,
          onChanged: (val) {
            if (val == null) return;
            if (isLeft) {
              ref.read(playerSettingsProvider.notifier).setLeftGesture(val);
            } else {
              ref.read(playerSettingsProvider.notifier).setRightGesture(val);
            }
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlayerGesture.values.map((g) {
              return RadioListTile<PlayerGesture>(
                title: Text(g.name[0].toUpperCase() + g.name.substring(1)),
                value: g,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatSeekDuration(int seconds) {
    if (seconds >= 60) {
      return '${seconds ~/ 60} min';
    }
    return '$seconds sec';
  }

  void _showDurationDialog(BuildContext context, WidgetRef ref, int current) {
    final options = [5, 10, 15, 20, 30, 60, 120];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text('Select Seek Duration'),
        content: RadioGroup<int>(
          groupValue: current,
          onChanged: (val) {
            if (val == null) return;
            ref.read(playerSettingsProvider.notifier).setSeekDuration(val);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((sec) {
              return RadioListTile<int>(
                title: Text(_formatSeekDuration(sec)),
                value: sec,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showResizeDialog(BuildContext context, WidgetRef ref, String current) {
    final options = ["Fit", "Zoom", "Stretch"];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text("Default Resize Mode"),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (val) {
            if (val == null) return;
            ref.read(playerSettingsProvider.notifier).setDefaultResizeMode(val);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((e) => RadioListTile<String>(title: Text(e), value: e))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showSubtitleDialog(
    BuildContext context,
    WidgetRef ref,
    PlayerSettings settings,
  ) {
    double size = settings.subtitleSize;
    bool showBackground = settings.subtitleBackgroundColor != 0;
    final isTv = ref.read(deviceProfileProvider).asData?.value.isTv ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            surfaceTintColor: Colors.transparent,
            title: const Text("Subtitle Settings"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Size: ${size.toInt()}"),
                TvSlider(
                  value: size,
                  min: 10,
                  max: 80,
                  divisions: 70,
                  step: 1.0,
                  onChanged: (v) => setState(() => size = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text("Background"),
                  value: showBackground,
                  onChanged: (v) => setState(() => showBackground = v),
                ),
              ],
            ),
            actions: [
              TvButton(
                showFocusHighlight: isTv,
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TvButton(
                autofocus: true,
                isPrimary: true,
                showFocusHighlight: isTv,
                onPressed: () {
                  // 0x99000000 is ~60% opacity black
                  final bg = showBackground ? 0x99000000 : 0x00000000;
                  ref
                      .read(playerSettingsProvider.notifier)
                      .setSubtitleSettings(size, settings.subtitleColor, bg);
                  Navigator.pop(ctx);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getPlayerDisplayName(String? playerId) {
    if (playerId == null) return 'Internal (media_kit)';
    final player = ExternalPlayerService.instance.getPlayerById(playerId);
    return player?.displayName ?? playerId;
  }

  void _showDefaultPlayerDialog(
    BuildContext context,
    WidgetRef ref,
    String? currentPlayerId,
  ) {
    final platformPlayers = ExternalPlayerService.instance
        .getPlayersForPlatform();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text('Default Player'),
        content: SingleChildScrollView(
          child: RadioGroup<String?>(
            groupValue: currentPlayerId,
            onChanged: (val) {
              ref.read(playerSettingsProvider.notifier).setPreferredPlayer(val);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String?>(
                  title: const Text('Internal (media_kit)'),
                  subtitle: const Text('Built-in player'),
                  secondary: const Icon(Icons.play_circle_filled_rounded),
                  value: null,
                ),
                const Divider(),
                ...platformPlayers.map((player) {
                  return RadioListTile<String?>(
                    title: Text(player.displayName),
                    secondary: Icon(player.icon),
                    value: player.id,
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDohProviderLabel(DohProvider provider, String customUrl) {
    switch (provider) {
      case DohProvider.cloudflare:
        return 'Cloudflare';
      case DohProvider.google:
        return 'Google';
      case DohProvider.custom:
        return customUrl.isNotEmpty
            ? Uri.tryParse(customUrl)?.host ?? customUrl
            : 'Custom (not set)';
    }
  }

  void _showDohProviderDialog(BuildContext context) {
    final controller = TextEditingController(
      text: DohService.instance.customUrl,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final current = DohService.instance.provider;
          return AlertDialog(
            surfaceTintColor: Colors.transparent,
            title: const Text('DoH Provider'),
            content: SingleChildScrollView(
              child: RadioGroup<DohProvider>(
                groupValue: current,
                onChanged: (val) {
                  if (val == null) return;
                  if (val == DohProvider.custom) {
                    setState(() {
                      DohService.instance.setProvider(DohProvider.custom);
                    });
                  } else {
                    DohService.instance.setProvider(val);
                    DohService.instance.clearCache();
                    Navigator.pop(ctx);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<DohProvider>(
                      title: const Text('Cloudflare'),
                      subtitle: const Text('1.1.1.1'),
                      value: DohProvider.cloudflare,
                    ),
                    RadioListTile<DohProvider>(
                      title: const Text('Google'),
                      subtitle: const Text('8.8.8.8'),
                      value: DohProvider.google,
                    ),
                    RadioListTile<DohProvider>(
                      title: const Text('Custom'),
                      subtitle: const Text('Enter your own endpoint'),
                      value: DohProvider.custom,
                    ),
                    if (current == DohProvider.custom)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'DoH Endpoint URL',
                            hintText: 'https://dns.example.com/dns-query',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (current == DohProvider.custom)
                TextButton(
                  onPressed: () {
                    final url = controller.text.trim();
                    if (url.isNotEmpty) {
                      DohService.instance.setCustomUrl(url);
                      DohService.instance.clearCache();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save'),
                ),
            ],
          );
        },
      ),
    );
  }
}
