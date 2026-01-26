import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/storage/storage_service.dart';

// Represents a historical item with progress
class HistoryItem {
  final MultimediaItem item;
  final int position;
  final int duration;
  final int timestamp;

  HistoryItem({
    required this.item,
    required this.position,
    required this.duration,
    required this.timestamp,
  });

  double get progress => duration > 0 ? position / duration : 0;
}

class WatchHistoryNotifier extends Notifier<List<HistoryItem>> {
  late StorageService _storage;

  @override
  List<HistoryItem> build() {
    _storage = ref.watch(storageServiceProvider);
    return _fetchHistory();
  }

  List<HistoryItem> _fetchHistory() {
    final rawList = _storage.getWatchHistory();
    return rawList.map((map) {
      return HistoryItem(
        item: MultimediaItem(
          title: map['title'] ?? '',
          url: map['url'] ?? '',
          posterUrl: map['posterUrl'] ?? '',
          bannerUrl: map['bannerUrl'],
          description: map['description'],
          isFolder: map['isFolder'] ?? false,
          provider: map['provider'],
        ),
        position: map['position'] ?? 0,
        duration: map['duration'] ?? 0,
        timestamp: map['timestamp'] ?? 0,
      );
    }).toList();
  }

  Future<void> saveProgress(
    MultimediaItem item,
    int position,
    int duration, {
    String? lastStreamUrl,
    String? lastEpisodeUrl,
  }) async {
    await _storage.saveProgress(
      item,
      position,
      duration,
      lastStreamUrl: lastStreamUrl,
      lastEpisodeUrl: lastEpisodeUrl,
    );
    state = _fetchHistory();
  }

  Future<void> removeFromHistory(String url) async {
    await _storage.removeFromHistory(url);
    state = _fetchHistory();
  }

  Future<void> clearAllHistory() async {
    await _storage.clearAllHistory();
    state = [];
  }
}

final watchHistoryProvider =
    NotifierProvider<WatchHistoryNotifier, List<HistoryItem>>(
      WatchHistoryNotifier.new,
    );
