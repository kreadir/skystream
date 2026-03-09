import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/base_provider.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/storage/storage_service.dart';
import '../../library/presentation/history_provider.dart';
import 'playback_launcher.dart';

class DetailsState {
  final AsyncValue<MultimediaItem?> details;
  final Map<int, List<Episode>> seasonMap;
  final int selectedSeason;
  final bool isMovie;

  const DetailsState({
    this.details = const AsyncLoading(),
    this.seasonMap = const {},
    this.selectedSeason = 1,
    this.isMovie = false,
  });

  DetailsState copyWith({
    AsyncValue<MultimediaItem?>? details,
    Map<int, List<Episode>>? seasonMap,
    int? selectedSeason,
    bool? isMovie,
  }) {
    return DetailsState(
      details: details ?? this.details,
      seasonMap: seasonMap ?? this.seasonMap,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      isMovie: isMovie ?? this.isMovie,
    );
  }
}

class DetailsController extends Notifier<DetailsState> {
  String? _initializedUrl;

  @override
  DetailsState build() => const DetailsState();

  void setSeason(int season) {
    if (state.seasonMap.containsKey(season)) {
      state = state.copyWith(selectedSeason: season);
    }
  }

  Future<void> loadDetails(
    MultimediaItem item, {
    bool autoPlay = false,
    BuildContext? context,
  }) async {
    if (_initializedUrl == item.url) return;
    _initializedUrl = item.url;

    state = state.copyWith(details: const AsyncLoading());

    final active = ref.read(activeProviderStateProvider);
    final manager = ref.read(extensionManagerProvider.notifier);

    try {
      if (item.provider == 'Local' ||
          item.provider == 'Torrent' ||
          item.provider == 'Remote') {
        var itemToUse = item;
        if (itemToUse.episodes == null || itemToUse.episodes!.isEmpty) {
          itemToUse = itemToUse.copyWith(
            episodes: [
              Episode(
                name: itemToUse.title,
                url: itemToUse.url,
                posterUrl: itemToUse.posterUrl,
              ),
            ],
          );
        }

        _processEpisodes(itemToUse.episodes);
        state = state.copyWith(details: AsyncData(itemToUse));

        if (autoPlay && context != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            handlePlayPress(context, itemToUse);
          });
        }
        return;
      }

      SkyStreamProvider? provider;
      if (item.provider != null) {
        try {
          provider = manager.getAllProviders().firstWhere(
            (p) => p.id == item.provider || p.name == item.provider,
          );
        } catch (_) {}
      }

      provider ??= active;

      if (provider != null) {
        final fetchedItem = await provider.getDetails(item.url);
        final withProvider = fetchedItem.copyWith(provider: provider.id);

        _processEpisodes(withProvider.episodes);
        state = state.copyWith(details: AsyncData(withProvider));

        if (autoPlay && context != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            handlePlayPress(context, withProvider);
          });
        }
      } else {
        throw Exception("No provider selected or found for this item");
      }
    } catch (e, st) {
      state = state.copyWith(details: AsyncError(e, st));
    }
  }

  void _processEpisodes(List<Episode>? episodes) {
    if (episodes == null || episodes.isEmpty) {
      state = state.copyWith(isMovie: false, seasonMap: {});
      return;
    }

    if (episodes.length == 1) {
      state = state.copyWith(
        isMovie: true,
        seasonMap: {1: episodes},
        selectedSeason: 1,
      );
      return;
    }

    final Map<int, List<Episode>> seasonMap = {};
    for (var ep in episodes) {
      final season = ep.season > 0 ? ep.season : 1;
      seasonMap.putIfAbsent(season, () => []).add(ep);
    }

    final sortedSeasons = seasonMap.keys.toList()..sort();
    final selectedSeason = sortedSeasons.isNotEmpty ? sortedSeasons.first : 1;

    state = state.copyWith(
      isMovie: false,
      seasonMap: seasonMap,
      selectedSeason: selectedSeason,
    );
  }

  void handlePlayPress(
    BuildContext context,
    MultimediaItem details, {
    Episode? specificEpisode,
  }) {
    if (specificEpisode != null) {
      ref
          .read(playbackLauncherProvider)
          .play(context, specificEpisode.url, baseItem: details);
      return;
    }

    if (state.isMovie) {
      ref
          .read(playbackLauncherProvider)
          .play(context, details.episodes!.first.url, baseItem: details);
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final lastEpisodeUrl = storage.getLastEpisodeUrl(details.url);
    final position = storage.getPosition(details.url);
    final historyHistory = ref.read(watchHistoryProvider);
    final duration = historyHistory
        .firstWhere(
          (i) => i.item.url == details.url,
          orElse: () => HistoryItem(
            item: details,
            position: 0,
            duration: 1,
            timestamp: 0,
          ),
        )
        .duration;

    final progress = duration > 0 ? (position / duration) * 100 : 0;

    if (lastEpisodeUrl != null) {
      final allEpisodes = <Episode>[];
      final sortedSeasons = state.seasonMap.keys.toList()..sort();
      for (var s in sortedSeasons) {
        allEpisodes.addAll(state.seasonMap[s]!);
      }

      final lastIndex = allEpisodes.indexWhere((e) => e.url == lastEpisodeUrl);
      if (lastIndex != -1) {
        if (progress > 95) {
          if (lastIndex + 1 < allEpisodes.length) {
            ref
                .read(playbackLauncherProvider)
                .play(
                  context,
                  allEpisodes[lastIndex + 1].url,
                  baseItem: details,
                );
            return;
          }
        }
        ref
            .read(playbackLauncherProvider)
            .play(context, lastEpisodeUrl, baseItem: details);
        return;
      }
    }

    final firstSeason = state.seasonMap.keys.toList()..sort();
    if (firstSeason.isNotEmpty) {
      final ep = state.seasonMap[firstSeason.first]?.first;
      if (ep != null) {
        ref
            .read(playbackLauncherProvider)
            .play(context, ep.url, baseItem: details);
      }
    }
  }
}

final detailsControllerProvider =
    NotifierProvider.autoDispose<DetailsController, DetailsState>(
      DetailsController.new,
    );
