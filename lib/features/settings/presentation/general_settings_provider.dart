import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/settings_repository.dart';

class GeneralSettings {
  final bool watchHistoryEnabled;

  const GeneralSettings({
    this.watchHistoryEnabled = true,
  });

  GeneralSettings copyWith({
    bool? watchHistoryEnabled,
  }) {
    return GeneralSettings(
      watchHistoryEnabled: watchHistoryEnabled ?? this.watchHistoryEnabled,
    );
  }
}

class GeneralSettingsNotifier extends Notifier<GeneralSettings> {
  @override
  GeneralSettings build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return GeneralSettings(
      watchHistoryEnabled: repository.isWatchHistoryEnabled(),
    );
  }

  Future<void> setWatchHistoryEnabled(bool enabled) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setWatchHistoryEnabled(enabled);
    state = state.copyWith(watchHistoryEnabled: enabled);
  }
}

final generalSettingsProvider =
    NotifierProvider<GeneralSettingsNotifier, GeneralSettings>(
  GeneralSettingsNotifier.new,
);
