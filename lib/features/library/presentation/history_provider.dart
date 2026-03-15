import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/history_repository.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../settings/presentation/general_settings_provider.dart';

export '../../../../core/storage/history_repository.dart' show HistoryItem;

final watchHistoryProvider = NotifierProvider<WatchHistoryNotifier, List<HistoryItem>>(() {
  return WatchHistoryNotifier();
});

class WatchHistoryNotifier extends Notifier<List<HistoryItem>> {
  late HistoryRepository _repository;

  @override
  List<HistoryItem> build() {
    _repository = ref.watch(historyRepositoryProvider);
    return _repository.getWatchHistory();
  }

  void refresh() {
    state = _repository.getWatchHistory();
  }

  Future<void> clearAllHistory() async {
    await _repository.clearAllHistory();
    refresh();
  }

  Future<void> removeFromHistory(String url) async {
    await _repository.removeFromHistory(url);
    refresh();
  }

  Future<void> saveProgress(
    MultimediaItem item,
    int position,
    int duration, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
    int? season,
    int? episode,
    String? episodeTitle,
  }) async {
    final enabled = ref.read(generalSettingsProvider).watchHistoryEnabled;
    if (!enabled) return;

    // For livestreams, we don't save progress but we still want it in history
    final isLivestream = item.contentType == MultimediaContentType.livestream;
    final finalPosition = isLivestream ? 0 : position;
    final finalDuration = isLivestream ? 0 : duration;

    await _repository.saveProgress(
      item,
      finalPosition,
      finalDuration,
      lastStreamUrl: lastStreamUrl,
      lastEpisodeUrl: lastEpisodeUrl,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
    );
    refresh();
  }
}
