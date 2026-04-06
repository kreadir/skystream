import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:video_view/video_view.dart'
    show VideoController, SubtitleTrackConfig, VideoControllerPlaybackState;

import '../../../../core/services/download_service.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/extensions/providers.dart';
import '../../../../core/models/torrent_status.dart';
import '../../../../core/storage/history_repository.dart';
import '../../library/presentation/history_provider.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/utils/app_utils.dart';
import '../../settings/presentation/player_settings_provider.dart';
import '../../../../core/services/local_proxy_service.dart';

class PlayerState {
  final bool isLoading;
  final String? errorMessage;
  final String playerTitle;
  final String? streamSubtitle;
  final List<StreamResult> streams;
  final int currentStreamIndex;
  final StreamResult? currentStream;
  final StreamResult? previousStream;
  final TorrentStatus? torrentStatus;
  final List<SubtitleFile> externalSubtitles;
  final bool isManualSwitch;
  final bool isOpeningStream;
  final bool isReverting;
  final bool showNextEpisodeOverlay;
  final String? nextEpisodeTitle;
  final int retryCountdown; // seconds remaining before auto-retry
  final bool isAdaptiveBufferingActive;
  final bool isBuffering;
  final bool showEpisodeList;
  final double playbackSpeed;
  final bool isLive;
  final double subtitleDelay;
  final String? imdbId;
  final int? tmdbId;

  /// Whether the active engine is video_view (ExoPlayer/AVPlayer) instead of media_kit.
  final bool useExoPlayer;
  final bool isSeekable;

  /// Non-null when a saved position was found; shows resume prompt instead of seeking silently.
  final int? resumePromptPosition;

  const PlayerState({
    this.isLoading = true,
    this.errorMessage,
    this.playerTitle = '',
    this.streamSubtitle,
    this.streams = const [],
    this.currentStreamIndex = 0,
    this.currentStream,
    this.previousStream,
    this.torrentStatus,
    this.externalSubtitles = const [],
    this.isManualSwitch = false,
    this.isOpeningStream = false,
    this.isReverting = false,
    this.showNextEpisodeOverlay = false,
    this.nextEpisodeTitle,
    this.retryCountdown = 0,
    this.isAdaptiveBufferingActive = false,
    this.isBuffering = false,
    this.showEpisodeList = false,
    this.playbackSpeed = 1.0,
    this.isLive = false,
    this.isSeekable = false,
    this.subtitleDelay = 0.0,
    this.imdbId,
    this.tmdbId,
    this.useExoPlayer = false,
    this.resumePromptPosition,
  });

  PlayerState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? playerTitle,
    String? streamSubtitle,
    List<StreamResult>? streams,
    int? currentStreamIndex,
    StreamResult? currentStream,
    StreamResult? previousStream,
    Object? torrentStatus = _keep,
    List<SubtitleFile>? externalSubtitles,
    bool? isManualSwitch,
    bool? isOpeningStream,
    bool? isReverting,
    bool? showNextEpisodeOverlay,
    String? nextEpisodeTitle,
    int? retryCountdown,
    bool? isAdaptiveBufferingActive,
    bool? isBuffering,
    bool? showEpisodeList,
    double? playbackSpeed,
    bool? isLive,
    bool? isSeekable,
    double? subtitleDelay,
    String? imdbId,
    int? tmdbId,
    bool? useExoPlayer,
    Object? resumePromptPosition = _keep,
  }) {
    return PlayerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      playerTitle: playerTitle ?? this.playerTitle,
      streamSubtitle: streamSubtitle ?? this.streamSubtitle,
      streams: streams ?? this.streams,
      currentStreamIndex: currentStreamIndex ?? this.currentStreamIndex,
      currentStream: currentStream ?? this.currentStream,
      previousStream: previousStream ?? this.previousStream,
      torrentStatus: torrentStatus == _keep
          ? this.torrentStatus
          : torrentStatus as TorrentStatus?,
      externalSubtitles: externalSubtitles ?? this.externalSubtitles,
      isManualSwitch: isManualSwitch ?? this.isManualSwitch,
      isOpeningStream: isOpeningStream ?? this.isOpeningStream,
      isReverting: isReverting ?? this.isReverting,
      showNextEpisodeOverlay:
          showNextEpisodeOverlay ?? this.showNextEpisodeOverlay,
      nextEpisodeTitle: nextEpisodeTitle ?? this.nextEpisodeTitle,
      retryCountdown: retryCountdown ?? this.retryCountdown,
      isAdaptiveBufferingActive:
          isAdaptiveBufferingActive ?? this.isAdaptiveBufferingActive,
      isBuffering: isBuffering ?? this.isBuffering,
      showEpisodeList: showEpisodeList ?? this.showEpisodeList,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLive: isLive ?? this.isLive,
      isSeekable: isSeekable ?? this.isSeekable,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      useExoPlayer: useExoPlayer ?? this.useExoPlayer,
      resumePromptPosition: resumePromptPosition == _keep
          ? this.resumePromptPosition
          : resumePromptPosition as int?,
    );
  }
}

// Sentinel so copyWith can distinguish "not passed" from "explicitly null".
const Object _keep = Object();

class PlayerController extends Notifier<PlayerState> {
  late Player _player;
  VideoController? _videoViewController;
  late MultimediaItem _item;
  late String _videoUrl;
  Episode? _episode;
  Timer? _torrentPollTimer;
  bool _isPolling = false;
  bool _isInitialized = false;

  /// On Linux, video_view uses libmpv (same as media_kit) — no benefit from switching.
  /// On other platforms, switch to ExoPlayer/AVPlayer for live/HLS streams.
  bool get _shouldUseVideoView {
    if (_videoViewController == null || Platform.isLinux) {
      return false;
    }

    // On Apple platforms (macOS/iOS), AVPlayer (VideoView) doesn't support DASH (.mpd).
    // We must use media_kit (mpv) for DASH on these platforms.
    if (Platform.isMacOS || Platform.isIOS || Platform.isWindows) {
      final url = _videoUrl.toLowerCase();
      if (url.contains('.mpd') || url.contains('manifest.mpd')) {
        return false;
      }
    }

    return state.isLive;
  }

  // Track last saved position for threshold-based saving
  Duration _lastSavedPosition = Duration.zero;
  static const double _saveThresholdPercent = 0.05; // 5% of video

  // Subscriptions to prevent leaks
  StreamSubscription? _videoParamsSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _rateSub;

  // Stall Watchdog state
  Duration? _lastPosition;
  DateTime? _lastPositionUpdateTime;
  bool _isRecoveringFromStall = false;

  final List<DateTime> _bufferDepletionTimes = [];
  Timer? _retryTimer;
  Timer? _stallTimer;
  int? _pendingResumeSeekPosition;
  bool _isApplyingPendingResumeSeek = false;

  @override
  PlayerState build() {
    ref.keepAlive();
    // Safety net: if the provider is somehow disposed without
    // disposeController() being called, clean up subscriptions.
    ref.onDispose(() {
      _torrentPollTimer?.cancel();
      _retryTimer?.cancel();
      _stallTimer?.cancel();
      _videoParamsSub?.cancel();
      _errorSub?.cancel();
      _playingSub?.cancel();
      _positionSub?.cancel();
      _durationSub?.cancel();
      _bufferingSub?.cancel();
      _completedSub?.cancel();
      _rateSub?.cancel();
    });
    return const PlayerState();
  }

  bool get isSeries =>
      _isInitialized && _item.contentType == MultimediaContentType.series;
  MultimediaItem? get multimediaItem => _isInitialized ? _item : null;
  String? get currentEpisodeUrl => _episode?.url ?? _videoUrl;

  Future<void> init({
    required Player player,
    required MultimediaItem item,
    required String videoUrl,
    Episode? episode,
    VideoController? videoViewController,
  }) async {
    state = const PlayerState(); // Reset stale state
    _player = player;
    _videoViewController = videoViewController;
    _videoUrl = videoUrl;
    _episode = episode;
    _pendingResumeSeekPosition = null;
    _isApplyingPendingResumeSeek = false;

    _item = item;

    String initialTitle = item.title;
    // Resolve Episode Title if Series
    if (item.episodes != null && item.episodes!.isNotEmpty) {
      if (item.episodes!.length > 1) {
        try {
          final ep = item.episodes!.firstWhere(
            (e) => e.url == videoUrl,
            orElse: () => item.episodes!.first,
          );

          if (ep.url == videoUrl) {
            String epTitle = "";
            if (ep.season > 0 && ep.episode > 0) {
              epTitle = "S${ep.season}:E${ep.episode}";
            } else if (ep.episode > 0) {
              epTitle = "E${ep.episode}";
            }

            if (ep.name.isNotEmpty && ep.name != "Episode ${ep.episode}") {
              epTitle = "$epTitle - ${ep.name}";
            }

            if (epTitle.isNotEmpty) {
              if (epTitle.startsWith(" - ")) epTitle = epTitle.substring(3);
              initialTitle = "${item.title} $epTitle";
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('PlayerController.init: $e');
        }
      }
    }

    final imdbId = item.syncData?['imdbId'] ?? item.syncData?['imdb_id'];
    final tmdbId = item.tmdbId;

    state = state.copyWith(
      playerTitle: initialTitle,
      streamSubtitle: "Searching for sources...",
      imdbId: imdbId,
      tmdbId: tmdbId,
    );

    _setupEventDrivenProgressSaving();
    _setupErrorListener();
    _setupVideoParamsListener();
    _setupDurationListener();
    _setupBufferingMonitor();
    _setupRateListener();
    _setupVideoViewListeners();

    state = state.copyWith(
      isLive:
          _item.contentType == MultimediaContentType.livestream ||
          _isLiveStream(_videoUrl),
    );

    _isInitialized = true;
    await _initStream();
    await applySubtitleSettings();
  }

  void _setupVideoViewListeners() {
    if (_videoViewController == null) return;

    _videoViewController!.mediaInfo.addListener(() {
      final info = _videoViewController!.mediaInfo.value;
      if (info != null) {
        if ((info.duration > 0 || info.isLive) && state.isLoading) {
          state = state.copyWith(isLoading: false);
        }

        // Sync isSeekable status from the native controller to our state
        if (info.isSeekable != state.isSeekable) {
          state = state.copyWith(isSeekable: info.isSeekable);
        }

        // Ensure metadata-based isLive is never overridden by false engine detection
        if (info.isLive && !state.isLive) {
          state = state.copyWith(isLive: true);
        }
      }
    });

    _videoViewController!.loading.addListener(() {
      final isBuffering = _videoViewController!.loading.value;
      if (isBuffering) {
        _handleBufferStall();
        _stallTimer?.cancel();
        _stallTimer = Timer(const Duration(milliseconds: 200), () {
          state = state.copyWith(isBuffering: true, isLoading: false);
        });
      } else {
        _stallTimer?.cancel();
        state = state.copyWith(
          isBuffering: false,
          isLoading: false, // Also clear main loading when buffering finishes
        );
      }
    });

    _videoViewController!.error.addListener(() {
      final error = _videoViewController!.error.value;
      if (error != null) {
        if (kDebugMode) debugPrint("VideoView Player Error: $error");
        if (state.isLoading || (_videoViewController!.position.value) == 0) {
          if (state.isManualSwitch) {
            revertToPreviousStream("Stream failed. Reverting...");
          } else {
            startRetryCountdown();
          }
        }
      }
    });

    _videoViewController!.playbackState.addListener(() {
      final playing =
          _videoViewController!.playbackState.value ==
          VideoControllerPlaybackState.playing;
      if (!playing) {
        saveProgress();
      } else {
        // ALWAYS clear loading/buffering if playback starts
        if (state.isLoading || state.isBuffering) {
          state = state.copyWith(isLoading: false, isBuffering: false);
        }
      }
    });

    _videoViewController!.finishedTimes.addListener(() {
      final completions = _videoViewController!.finishedTimes.value;
      if (completions > 0) {
        final isLive =
            _item.contentType == MultimediaContentType.livestream ||
            _isLiveStream(_videoUrl);
        if (isLive && state.currentStream != null) {
          changeStream(state.currentStream!, resetPosition: true);
        }
      }
    });

    _videoViewController!.position.addListener(() {
      if (!state.useExoPlayer) return;

      final posMs = _videoViewController!.position.value;
      final durationMs = _videoViewController!.mediaInfo.value?.duration ?? 0;

      // If position is advancing, we are definitely not loading anymore
      if (posMs > 0 && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }

      if (durationMs == 0) return;

      final currentPct = posMs / durationMs;
      final lastPct = _lastSavedPosition.inMilliseconds / durationMs;

      if ((currentPct - lastPct).abs() >= _saveThresholdPercent) {
        saveProgress();
        _lastSavedPosition = Duration(milliseconds: posMs);
      }

      if (_item.contentType == MultimediaContentType.series) {
        final remainingSecs = (durationMs - posMs) / 1000;
        if (remainingSecs <= 15 &&
            remainingSecs > 0 &&
            !state.showNextEpisodeOverlay) {
          int? currentIndex;
          if (_episode != null) {
            currentIndex = _item.episodes?.indexWhere(
              (e) => e.url == _episode!.url,
            );
          } else {
            currentIndex = _item.episodes?.indexWhere(
              (e) => e.url == _videoUrl,
            );
          }

          if (currentIndex != null &&
              currentIndex != -1 &&
              currentIndex < _item.episodes!.length - 1) {
            final next = _item.episodes![currentIndex + 1];
            state = state.copyWith(
              showNextEpisodeOverlay: true,
              nextEpisodeTitle: next.name,
            );
          }
        } else if (remainingSecs > 15 && state.showNextEpisodeOverlay) {
          state = state.copyWith(showNextEpisodeOverlay: false);
        }
      }
    });
  }

  void _setupRateListener() {
    _rateSub?.cancel();
    _rateSub = _player.stream.rate.listen((rate) {
      state = state.copyWith(playbackSpeed: rate);
    });
  }

  void _setupDurationListener() {
    _durationSub?.cancel();
    _durationSub = _player.stream.duration.listen((duration) {
      if (duration > Duration.zero && _pendingResumeSeekPosition != null) {
        unawaited(_flushPendingResumeSeek());
      }
    });
  }

  void _setupVideoParamsListener() {
    _videoParamsSub = _player.stream.videoParams.listen((args) {
      if (args.w != null && args.w! > 0) {
        if (state.isLoading) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  void _setupBufferingMonitor() {
    _bufferingSub?.cancel();
    _bufferingSub = _player.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        _handleBufferStall();
        // Delay showing the loader to avoid flicker on micro-stalls
        _stallTimer?.cancel();
        _stallTimer = Timer(const Duration(milliseconds: 200), () {
          state = state.copyWith(isBuffering: true);
        });
      } else {
        _stallTimer?.cancel();
        state = state.copyWith(isBuffering: false);
      }
    });
  }

  void _handleBufferStall() {
    if (_isLiveStream(_videoUrl)) return;

    final now = DateTime.now();
    _bufferDepletionTimes.add(now);

    // Keep only stalls in the last 60 seconds
    _bufferDepletionTimes.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 60),
    );

    if (_bufferDepletionTimes.length >= 2 && !state.isAdaptiveBufferingActive) {
      if (kDebugMode) {
        debugPrint(
          "Multiple buffer stalls detected. Activating adaptive buffering.",
        );
      }
      state = state.copyWith(isAdaptiveBufferingActive: true);

      // Re-apply properties with aggressive buffering
      if (_player.platform is NativePlayer) {
        final settings = ref.read(playerSettingsProvider).asData?.value;
        final readahead = (settings?.readaheadSeconds ?? 180) * 2;
        final native = _player.platform as NativePlayer;
        // Double the readahead and cache for VOD if stalled
        if (_player.state.duration > Duration.zero) {
          native.setProperty('demuxer-readahead-secs', '$readahead');
          native.setProperty('cache-secs', '$readahead');
        }
      }
    }
  }

  void _setupErrorListener() {
    _errorSub = _player.stream.error.listen((error) {
      if (kDebugMode) debugPrint("Player Error: $error");
      if (error.toString().toLowerCase().contains("abort")) return;

      if (state.isLoading || _player.state.position == Duration.zero) {
        if (state.isManualSwitch) {
          revertToPreviousStream("Stream failed. Reverting...");
        } else {
          startRetryCountdown();
        }
      }
    });
  }

  void startRetryCountdown() {
    _retryTimer?.cancel();
    state = state.copyWith(retryCountdown: 5);

    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.retryCountdown > 1) {
        state = state.copyWith(retryCountdown: state.retryCountdown - 1);
      } else {
        timer.cancel();
        state = state.copyWith(retryCountdown: 0);
        retryNextStream();
      }
    });
  }

  void cancelRetry() {
    _retryTimer?.cancel();
    state = state.copyWith(retryCountdown: 0, isLoading: false);
  }

  void _setupEventDrivenProgressSaving() {
    _playingSub?.cancel();
    _playingSub = _player.stream.playing.listen((isPlaying) {
      if (!isPlaying) {
        saveProgress();
        _torrentPollTimer?.cancel();
        _torrentPollTimer = null;
      } else {
        // Playback started: CLEAR EVERYTHING
        if (state.isLoading || state.isBuffering) {
          state = state.copyWith(isLoading: false, isBuffering: false);
        }

        if (state.torrentStatus != null && _torrentPollTimer == null) {
          startTorrentPolling();
        }
      }
    });

    _completedSub?.cancel();
    _completedSub = _player.stream.completed.listen((isCompleted) {
      if (isCompleted) {
        final isLive =
            _item.contentType == MultimediaContentType.livestream ||
            _isLiveStream(_videoUrl);
        if (isLive && state.currentStream != null) {
          if (kDebugMode) {
            debugPrint("Live stream reached EOF. Forcing auto-reconnect...");
          }
          // Emulate ExoPlayer's BEHIND_LIVE_WINDOW by re-initializing the failed stream internally
          changeStream(state.currentStream!, resetPosition: true);
        }
      }
    });

    _positionSub?.cancel();
    _positionSub = _player.stream.position.listen((pos) {
      // Clear initial loading as soon as we have a valid position update
      if (pos.inMilliseconds > 0 && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }

      final now = DateTime.now();

      // --- Stall Watchdog Logic ---
      if (_player.state.playing && !state.isBuffering && !state.isLoading) {
        if (_lastPosition != null && _lastPosition == pos) {
          final stallDuration = _lastPositionUpdateTime != null
              ? now.difference(_lastPositionUpdateTime!)
              : Duration.zero;

          if (stallDuration.inSeconds >= 5 && !_isRecoveringFromStall) {
            if (kDebugMode) {
              debugPrint(
                "Watchdog: Silent stall detected (5s). Kicking engine...",
              );
            }
            _isRecoveringFromStall = true;

            // Recovery: Toggle play/pause or trigger a re-sync
            if (state.isLive && state.currentStream != null) {
              changeStream(state.currentStream!, resetPosition: false);
            } else {
              _player.play(); // Simple kick
            }

            // prevent multi-trigger
            Future.delayed(const Duration(seconds: 10), () {
              _isRecoveringFromStall = false;
            });
          }
        } else {
          _lastPosition = pos;
          _lastPositionUpdateTime = now;
        }
      } else {
        _lastPosition = pos;
        _lastPositionUpdateTime = now;
      }
      // -----------------------------

      final duration = _player.state.duration;
      if (duration == Duration.zero) return;

      final currentPct = pos.inMilliseconds / duration.inMilliseconds;
      final lastPct =
          _lastSavedPosition.inMilliseconds / duration.inMilliseconds;

      if ((currentPct - lastPct).abs() >= _saveThresholdPercent) {
        saveProgress();
        _lastSavedPosition = pos;
      }

      // Next Episode Detection (Series only, trigger 15s before end)
      if (_item.contentType == MultimediaContentType.series) {
        final remaining = duration - pos;
        if (remaining.inSeconds <= 15 &&
            remaining.inSeconds > 0 &&
            !state.showNextEpisodeOverlay) {
          // Use _episode if available, otherwise fallback to URL matching
          int? currentIndex;
          if (_episode != null) {
            currentIndex = _item.episodes?.indexWhere(
              (e) => e.url == _episode!.url,
            );
          } else {
            currentIndex = _item.episodes?.indexWhere(
              (e) => e.url == _videoUrl,
            );
          }

          if (currentIndex != null &&
              currentIndex != -1 &&
              currentIndex < _item.episodes!.length - 1) {
            final next = _item.episodes![currentIndex + 1];
            state = state.copyWith(
              showNextEpisodeOverlay: true,
              nextEpisodeTitle: next.name,
            );
          }
        } else if (remaining.inSeconds > 15 && state.showNextEpisodeOverlay) {
          state = state.copyWith(showNextEpisodeOverlay: false);
        }
      }
    });
  }

  Future<void> _initStream() async {
    if (await _handleSpecialProviders()) return;

    final activeProvider = _resolveProvider();
    if (activeProvider == null) {
      state = state.copyWith(
        errorMessage: "No provider selected.",
        isLoading: false,
      );
      return;
    }

    try {
      if (_videoUrl.isNotEmpty) {
        state = state.copyWith(
          streamSubtitle: "Initializing stream...",
          isLoading: true,
        );
        if (await _handleFallbackTorrent()) return;

        final streams = await activeProvider.loadStreams(_videoUrl);
        if (streams.isNotEmpty) {
          final initialIndex = _findSavedStreamIndex(streams);
          state = state.copyWith(
            streams: streams,
            currentStreamIndex: initialIndex,
          );

          // PERFORMANCE: Parallel check the first few streams (health check)
          // This avoids waiting for a timeout on a dead stream if a working one is available
          final checkCount = streams.length > 3 ? 3 : streams.length;
          final workingIndex = await _findFirstWorkingStream(
            streams,
            startIndex: initialIndex,
            limit: checkCount,
          );

          await loadStreamAtIndex(workingIndex);
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading streams: $e");
    }

    state = state.copyWith(errorMessage: "No streams found.", isLoading: false);
  }

  Future<bool> _handleSpecialProviders() async {
    if (_item.provider == 'Remote' ||
        _item.provider == 'Local' ||
        _item.provider == 'Torrent' ||
        AppUtils.isLocalFile(_videoUrl)) {
      final isTorrent =
          _item.provider == 'Torrent' ||
          _videoUrl.startsWith("magnet:") ||
          _videoUrl.endsWith(".torrent");

      final stream = StreamResult(
        url: _videoUrl,
        source: isTorrent ? "Torrent" : "Video",
        headers: {},
      );

      state = state.copyWith(streams: [stream], currentStreamIndex: 0);
      await loadStreamAtIndex(0);
      return true;
    }
    return false;
  }

  Future<bool> _handleFallbackTorrent() async {
    if (_videoUrl.startsWith("magnet:") || _videoUrl.endsWith(".torrent")) {
      final stream = StreamResult(
        url: _videoUrl,
        source: "Torrent",
        headers: {},
      );
      state = state.copyWith(streams: [stream], currentStreamIndex: 0);
      await loadStreamAtIndex(0);
      return true;
    }
    return false;
  }

  SkyStreamProvider? _resolveProvider() {
    final activeState = ref.read(activeProviderStateProvider);
    final manager = ref.read(extensionManagerProvider.notifier);

    if (_item.provider != null) {
      try {
        final val = _item.provider!;
        return manager.getAllProviders().firstWhere(
          (p) => p.packageName == val || p.name == val,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('PlayerController._resolveProvider: $e');
      }
    }
    return activeState;
  }

  int _findSavedStreamIndex(List<StreamResult> streams) {
    try {
      final historyRepo = ref.read(historyRepositoryProvider);
      final isSeries = _item.contentType == MultimediaContentType.series;

      String? lastUrl;
      if (isSeries) {
        lastUrl = historyRepo.getLastStreamUrl(_item.url);
      }

      if (lastUrl == null) {
        final historyList = ref.read(watchHistoryProvider);
        final previousState = historyList.firstWhere(
          (h) => h.item.url == _item.url,
          orElse: () => HistoryItem(
            item: _item,
            position: 0,
            duration: 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        lastUrl = previousState.lastStreamUrl;
      }

      if (lastUrl != null) {
        final foundIndex = streams.indexWhere((s) => s.url == lastUrl);
        if (foundIndex != -1) return foundIndex;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error checking saved stream quality: $e");
    }
    return 0;
  }

  Episode? _resolveCurrentEpisode() {
    if (_episode != null) return _episode;
    if (_item.contentType != MultimediaContentType.series) return null;
    return _item.episodes?.firstWhereOrNull((e) => e.url == _videoUrl);
  }

  Future<void> loadStreamAtIndex(int index) async {
    if (index < 0 || index >= state.streams.length) return;

    final stream = state.streams[index];
    final rawProviderName =
        _item.provider ??
        ref.read(activeProviderStateProvider)?.name ??
        "Unknown";
    final providerName = _getProviderDisplayName(rawProviderName);

    state = state.copyWith(
      currentStreamIndex: index,
      currentStream: stream,
      isLoading: true,
      streamSubtitle: "$providerName - ${stream.source}",
      externalSubtitles: stream.subtitles ?? [],
      isLive:
          _item.contentType == MultimediaContentType.livestream ||
          _isLiveStream(stream.url),
    );

    try {
      final playUrl = await _resolveStreamUrl(stream);
      if (playUrl == null) throw Exception("Failed to resolve stream URL");

      if (playUrl.contains("index=")) {
        startTorrentPolling(playUrl);
      } else {
        stopTorrentPolling();
      }

      state = state.copyWith(
        streamSubtitle: "$providerName - ${stream.source}",
      );

      final headers = stream.headers ?? {};
      await _applyPlaybackProperties(headers, stream);

      // Phase 7: Route to correct engine
      if (_shouldUseVideoView) {
        String finalUrl = playUrl;
        // JIO BD / play.php Fix: If we are using the native engine and the URL is a known
        // non-standard redirector (like play.php or index.php), wrap it in our LocalProxyService.
        // This ensures the content is sniffed/rewritten as HLS and served with a .m3u8 extension.
        if (finalUrl.contains('play.php') || finalUrl.contains('index.php')) {
          finalUrl = LocalProxyService.instance.getProxyUrl(
            finalUrl,
            headers: headers,
            forceM3u8Extension: true,
          );
          if (kDebugMode) {
            debugPrint("[PLAYER] Proxied non-standard HLS: $finalUrl");
          }
        }

        final subs = state.externalSubtitles;
        if (subs.isNotEmpty) {
          _videoViewController!.openWithSubtitles(
            finalUrl,
            headers: headers,
            subtitles: subs
                .map(
                  (s) => SubtitleTrackConfig(
                    uri: s.url,
                    mimeType: s.url.toLowerCase().endsWith('.vtt')
                        ? 'text/vtt'
                        : 'application/x-subrip',
                    language: s.lang ?? 'und',
                  ),
                )
                .toList(),
            drmKey: stream.drmKey,
            drmKid: stream.drmKid,
          );
        } else {
          _videoViewController!.open(
            finalUrl,
            headers: headers,
            drmKey: stream.drmKey,
            drmKid: stream.drmKid,
          );
        }
        state = state.copyWith(useExoPlayer: true);
      } else {
        await _player.open(Media(playUrl, httpHeaders: headers));
        state = state.copyWith(useExoPlayer: false);
      }

      final historyRepo = ref.read(historyRepositoryProvider);
      final isSeries = _item.contentType == MultimediaContentType.series;

      int savedPos = 0;
      if (isSeries) {
        final ep = _resolveCurrentEpisode();
        final historyEpisodeUrl = ep?.url ?? _videoUrl;
        savedPos = historyRepo.getEpisodePosition(
          historyEpisodeUrl,
          mainUrl: _item.url,
          season: ep?.season,
          episode: ep?.episode,
        );
      } else {
        savedPos = historyRepo.getPosition(_item.url);
      }

      if (savedPos > 0) {
        // Show prompt instead of seeking silently — user may want to start over.
        state = state.copyWith(resumePromptPosition: savedPos);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Stream $index failed: $e");
      retryNextStream();
    }
  }

  /// Called when the user taps "Resume" in the resume prompt overlay.
  Future<void> confirmResume() async {
    final pos = state.resumePromptPosition;
    state = state.copyWith(resumePromptPosition: null);
    if (pos != null && pos > 0) {
      _pendingResumeSeekPosition = pos;
      await _flushPendingResumeSeek();
    }
  }

  /// Called when the user taps "Start Over" or the prompt auto-dismisses.
  void dismissResumePrompt() {
    _pendingResumeSeekPosition = null;
    state = state.copyWith(resumePromptPosition: null);
  }

  Future<void> changeStream(
    StreamResult stream, {
    bool isRevert = false,
    bool resetPosition = false,
  }) async {
    if (!isRevert) {
      state = state.copyWith(
        previousStream: state.currentStream,
        isManualSwitch: true,
      );
    }

    final rawPName =
        _item.provider ??
        ref.read(activeProviderStateProvider)?.name ??
        'Unknown';
    final pName = _getProviderDisplayName(rawPName);

    // Capture current position before we switch engines/streams.
    // Read from whichever engine is currently active.
    final oldPos = state.useExoPlayer
        ? Duration(milliseconds: _videoViewController?.position.value ?? 0)
        : _player.state.position;

    state = state.copyWith(isOpeningStream: true);

    try {
      final playUrl = await _resolveStreamUrl(stream);
      if (playUrl == null) throw Exception("Failed to resolve stream URL");

      state = state.copyWith(
        isLoading: true,
        currentStream: stream,
        externalSubtitles: stream.subtitles ?? [],
        isLive:
            _item.contentType == MultimediaContentType.livestream ||
            _isLiveStream(playUrl),
      );

      state = state.copyWith(streamSubtitle: "$pName - ${stream.source}");

      if (playUrl.contains("index=")) {
        startTorrentPolling(playUrl);
      } else {
        stopTorrentPolling();
      }

      final headers = stream.headers ?? {};
      await _applyPlaybackProperties(headers, stream);

      // Phase 7: Route to correct engine
      if (_shouldUseVideoView) {
        String finalUrl = playUrl;
        // JIO BD / play.php Fix: If we are using the native engine and the URL is a known
        // non-standard redirector (like play.php or index.php), wrap it in our LocalProxyService.
        // This ensures the content is sniffed/rewritten as HLS and served with a .m3u8 extension.
        if (finalUrl.contains('play.php') || finalUrl.contains('index.php')) {
          finalUrl = LocalProxyService.instance.getProxyUrl(
            finalUrl,
            headers: headers,
            forceM3u8Extension: true,
          );
        }

        final subs = state.externalSubtitles;
        if (subs.isNotEmpty) {
          _videoViewController!.openWithSubtitles(
            finalUrl,
            headers: headers,
            subtitles: subs
                .map(
                  (s) => SubtitleTrackConfig(
                    uri: s.url,
                    mimeType: s.url.toLowerCase().endsWith('.vtt')
                        ? 'text/vtt'
                        : 'application/x-subrip',
                    language: s.lang ?? 'und',
                  ),
                )
                .toList(),
            drmKey: stream.drmKey,
            drmKid: stream.drmKid,
          );
        } else {
          _videoViewController!.open(
            finalUrl,
            headers: headers,
            drmKey: stream.drmKey,
            drmKid: stream.drmKid,
          );
        }
        state = state.copyWith(useExoPlayer: true);
      } else {
        await _player.open(Media(playUrl, httpHeaders: headers));
        state = state.copyWith(useExoPlayer: false);
      }

      if (oldPos > Duration.zero && !resetPosition) {
        await _safeSeekTo(oldPos.inMilliseconds);
      } else if (resetPosition) {
        await _player.seek(Duration.zero);
      }

      state = state.copyWith(
        isLoading: false,
        isReverting: isRevert ? false : state.isReverting,
        isManualSwitch: isRevert ? false : state.isManualSwitch,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Change stream failed: $e");
      if (isRevert) {
        state = state.copyWith(
          errorMessage: "Revert failed: $e",
          isReverting: false,
        );
      } else {
        revertToPreviousStream("Switch failed. Reverting...");
      }
    } finally {
      state = state.copyWith(isOpeningStream: false);
    }
  }

  void retryNextStream() {
    if (state.currentStreamIndex < state.streams.length - 1) {
      loadStreamAtIndex(state.currentStreamIndex + 1);
    } else {
      state = state.copyWith(
        errorMessage: "All streams failed.",
        isLoading: false,
      );
    }
  }

  void revertToPreviousStream(String reason) {
    if (state.previousStream == null || state.isReverting) {
      if (state.previousStream == null) {
        state = state.copyWith(
          errorMessage: "Stream failed. No fallback available.",
          isLoading: false,
          isManualSwitch: false,
        );
      }
      return;
    }

    state = state.copyWith(isReverting: true);
    // Note: Revert toast / SnackBar will need to be handled by the UI
    // The UI can listen to state changes or errors, but for now we just change the stream
    changeStream(state.previousStream!, isRevert: true);
  }

  Future<void> onTorrentFileSelected(int index) async {
    state = state.copyWith(isLoading: true);
    try {
      final url = await ref
          .read(torrentServiceProvider)
          .getStreamUrlForFileIndex(index);
      if (url != null && state.currentStream != null) {
        String fileLabel = "Torrent File $index";
        try {
          final files =
              state.torrentStatus?.data['file_stats'] as List<dynamic>?;
          final file = files?.firstWhere(
            (f) => f['id'] == index,
            orElse: () => null,
          );
          if (file != null) {
            fileLabel = (file['path'] as String).split('/').last;
            state = state.copyWith(playerTitle: fileLabel);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('PlayerController.onTorrentFileSelected: $e');
          }
        }

        final newStream = StreamResult(
          url: url,
          source: "Torrent ($fileLabel)",
          headers: {},
        );
        changeStream(newStream, resetPosition: true);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Failed to switch file: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> playNextEpisode() async {
    if (_item.contentType != MultimediaContentType.series) return;

    int? currentIndex;
    if (_episode != null) {
      currentIndex = _item.episodes?.indexWhere((e) => e.url == _episode!.url);
    } else {
      currentIndex = _item.episodes?.indexWhere((e) => e.url == _videoUrl);
    }

    if (currentIndex != null &&
        currentIndex != -1 &&
        currentIndex < _item.episodes!.length - 1) {
      final nextEpisode = _item.episodes![currentIndex + 1];

      // Smart Next Episode: Check for downloaded version
      final downloadService = ref.read(downloadServiceProvider);
      final localFile = await downloadService.getDownloadedFile(
        _item,
        episode: nextEpisode,
      );

      final String finalUrl = localFile?.path ?? nextEpisode.url;
      final bool isLocal = localFile != null;

      // Update video URL and episode, then refresh
      _videoUrl = finalUrl;
      _episode = nextEpisode;
      state = state.copyWith(
        playerTitle: "${_item.title} - ${nextEpisode.name}",
        showNextEpisodeOverlay: false,
        isLoading: true,
        streamSubtitle: isLocal ? "Local - Downloaded" : "Fetching sources...",
      );

      await _initStream();
    }
  }

  void dismissNextEpisodeOverlay() {
    state = state.copyWith(showNextEpisodeOverlay: false);
  }

  void toggleEpisodeList() {
    state = state.copyWith(showEpisodeList: !state.showEpisodeList);
  }

  Future<void> loadEpisode(Episode episode) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, showEpisodeList: false);

    _episode = episode;
    _videoUrl = episode.url;

    // Smart load: Check for downloaded version
    final downloadService = ref.read(downloadServiceProvider);
    final localFile = await downloadService.getDownloadedFile(
      _item,
      episode: episode,
    );

    final String finalUrl = localFile?.path ?? episode.url;
    final bool isLocal = localFile != null;

    _videoUrl = finalUrl;
    state = state.copyWith(
      playerTitle: "${_item.title} - ${episode.name}",
      streamSubtitle: isLocal ? "Local - Downloaded" : "Fetching sources...",
    );

    await _initStream();
  }

  void saveProgress() {
    try {
      // Read position/duration from whichever engine is currently active.
      final int pos;
      final int dur;
      if (state.useExoPlayer && _videoViewController != null) {
        pos = _videoViewController!.position.value;
        dur = _videoViewController!.mediaInfo.value?.duration ?? 0;
      } else {
        pos = _player.state.position.inMilliseconds;
        dur = _player.state.duration.inMilliseconds;
      }
      final isLivestream =
          _item.contentType == MultimediaContentType.livestream;

      // Livestreams: save to history without progress (position=0, duration=0)
      if (isLivestream) {
        final pId =
            _item.provider ??
            ref.read(activeProviderStateProvider)?.packageName ??
            'Unknown';
        final itemToSave = _item.copyWith(provider: pId);
        ref
            .read(watchHistoryProvider.notifier)
            .saveProgress(
              itemToSave,
              0,
              0,
              lastStreamUrl: null, // Don't save temporary links for livestreams
              lastEpisodeUrl: null,
            );
        return;
      }

      if (dur < 30000) return;

      final double progress = (pos / dur) * 100;
      final bool isSeries = _item.contentType == MultimediaContentType.series;
      final historyNotifier = ref.read(watchHistoryProvider.notifier);

      final pId =
          _item.provider ??
          ref.read(activeProviderStateProvider)?.packageName ??
          'Unknown';
      final itemToSave = _item.copyWith(provider: pId);

      // Identify current episode if series
      final currentEpisode = _resolveCurrentEpisode();

      // Handle Completion / Next Episode Logic
      if (progress >= 95) {
        if (!isSeries) {
          historyNotifier.removeFromHistory(_item.url);
          return;
        } else if (currentEpisode != null) {
          // Find next episode
          final currentIndex = _item.episodes!.indexOf(currentEpisode);
          if (currentIndex != -1 && currentIndex < _item.episodes!.length - 1) {
            final nextEpisode = _item.episodes![currentIndex + 1];
            // Save NEXT episode as current progress (reset to 0)
            historyNotifier.saveProgress(
              itemToSave,
              0,
              0,
              lastStreamUrl: null,
              lastEpisodeUrl: nextEpisode.url,
              season: nextEpisode.season,
              episode: nextEpisode.episode,
              episodeTitle: nextEpisode.name,
            );
            return;
          } else {
            // Last episode of the series completed
            historyNotifier.removeFromHistory(_item.url);
            return;
          }
        }
      }

      // Normal Progress Saving
      if (progress > 5 || isSeries) {
        historyNotifier.saveProgress(
          itemToSave,
          pos,
          dur,
          lastStreamUrl: state.currentStream?.url,
          lastEpisodeUrl: currentEpisode?.url ?? _videoUrl,
          season: currentEpisode?.season,
          episode: currentEpisode?.episode,
          episodeTitle: currentEpisode?.name,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint("History save failed: $e");
    }
  }

  void startTorrentPolling([String? activeStreamUrl]) {
    _torrentPollTimer?.cancel();

    Future<void> poll() async {
      if (_isPolling) return;
      _isPolling = true;
      try {
        final status = await ref
            .read(torrentServiceProvider)
            .getCurrentStatus();
        if (status != null) {
          final urlToCheck = activeStreamUrl ?? state.currentStream?.url;
          if (urlToCheck?.contains("index=") ?? false) {
            try {
              final uri = Uri.parse(urlToCheck!);
              final indexStr = uri.queryParameters['index'];
              if (indexStr != null) {
                final index = int.tryParse(indexStr);
                final files = status.data['file_stats'] as List<dynamic>?;
                final file = files?.firstWhere(
                  (f) => f['id'] == index,
                  orElse: () => null,
                );
                if (file != null) {
                  final name = (file['path'] as String).split('/').last;
                  if (state.playerTitle != name) {
                    state = state.copyWith(playerTitle: name);
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('PlayerController.startTorrentPolling: $e');
              }
            }
          }
          state = state.copyWith(torrentStatus: status);
        }
      } finally {
        _isPolling = false;
      }
    }

    poll();
    _torrentPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => poll(),
    );
  }

  void stopTorrentPolling() {
    _torrentPollTimer?.cancel();
    _torrentPollTimer = null;
    if (state.torrentStatus != null) {
      state = state.copyWith(torrentStatus: null);
    }
  }

  void disposeController() {
    _torrentPollTimer?.cancel();
    _torrentPollTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _stallTimer?.cancel();
    _stallTimer = null;

    _videoParamsSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _rateSub?.cancel();

    saveProgress();
    ref.read(torrentServiceProvider).stop();
    Future.microtask(() {
      state = const PlayerState();
    });
  }

  Future<int> _findFirstWorkingStream(
    List<StreamResult> streams, {
    required int startIndex,
    required int limit,
  }) async {
    if (streams.isEmpty) return 0;

    // Safety check for start index
    final int start = startIndex.clamp(0, streams.length - 1);

    // Extract candidates (circular if needed, though usually not)
    final candidates = <int>[];
    for (int i = 0; i < limit; i++) {
      final idx = (start + i) % streams.length;
      if (!candidates.contains(idx)) candidates.add(idx);
    }

    if (candidates.length <= 1) return start;

    try {
      if (kDebugMode) {
        debugPrint(
          "Starting parallel health check for ${candidates.length} streams",
        );
      }
      final results = await Future.wait(
        candidates.map((idx) async {
          final s = streams[idx];
          // Skip torrents/local files from parallel check
          if (s.url.startsWith("magnet:") ||
              s.url.endsWith(".torrent") ||
              s.url.startsWith("/")) {
            return MapEntry(idx, true);
          }

          try {
            final uri = Uri.parse(s.url);
            // Use a short timeout for health check
            final resp = await http
                .head(uri, headers: s.headers)
                .timeout(const Duration(seconds: 3));
            return MapEntry(idx, resp.statusCode < 400);
          } catch (_) {
            return MapEntry(idx, false);
          }
        }),
      );

      // Return first one that responded positively in the original order of preference
      for (final entry in results) {
        if (entry.value) {
          if (kDebugMode) debugPrint("Stream ${entry.key} is healthy");
          return entry.key;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Parallel check failed: $e");
    }

    return start; // Fallback to initial
  }

  String _getProviderDisplayName(String providerName) {
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager.getAllProviders().firstWhere(
        (p) => p.packageName == providerName || p.name == providerName,
      );
      if (p.isDebug) return "${p.name} [DEBUG]";
      return p.name;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlayerController._getProviderDisplayName: $e');
      }
    }
    return providerName;
  }

  Future<String?> _resolveStreamUrl(StreamResult stream) async {
    if (stream.url.startsWith("magnet:") ||
        stream.url.endsWith(".torrent") ||
        (stream.url.startsWith("/") && stream.source.contains("Torrent"))) {
      state = state.copyWith(streamSubtitle: "Initializing Torrent Engine...");
      final torrentUrl = await ref
          .read(torrentServiceProvider)
          .getStreamUrl(stream.url);
      if (torrentUrl != null) return torrentUrl;
      return null;
    }

    return AppUtils.normalizeUrl(stream.url);
  }

  /// Applies per-playback MPV properties (headers, cookies, DRM).
  Future<void> _applyPlaybackProperties(
    Map<String, String> headers,
    StreamResult stream,
  ) async {
    // Debug: log what DRM fields the stream has so failures are traceable.
    if (kDebugMode) {
      debugPrint(
        '[DRM] stream drmKid=${stream.drmKid} '
        'drmKey=${stream.drmKey} '
        'licenseUrl=${stream.licenseUrl}',
      );
    }

    if (_player.platform is NativePlayer) {
      final native = _player.platform as NativePlayer;

      final lowerHeaders = headers.map((k, v) => MapEntry(k.toLowerCase(), v));

      // Propagate ALL provided headers to MPV (Critical for cookies/auth)
      if (lowerHeaders.isNotEmpty) {
        final List<String> headerFields = [];
        lowerHeaders.forEach((key, value) {
          // FFmpeg/libavformat "headers" option standard is CRLF terminated strings.
          // Comma-separated list is also accepted by MPV but CRLF is more robust.
          headerFields.add('$key: $value');
        });

        if (headerFields.isNotEmpty) {
          // Join with \r\n and ensure it ends with \r\n
          final fields = '${headerFields.join('\r\n')}\r\n';
          if (kDebugMode) {
            debugPrint('Player: Setting http-header-fields: $fields');
          }
          await native.setProperty('http-header-fields', fields);
        }
      }

      // Also set dedicated properties for better compatibility
      if (lowerHeaders.containsKey('user-agent')) {
        await native.setProperty('user-agent', lowerHeaders['user-agent']!);
      }
      if (lowerHeaders.containsKey('referer')) {
        await native.setProperty('referrer', lowerHeaders['referer']!);
      }

      // 0. Hardware decoding preference
      final settings = ref.read(playerSettingsProvider).asData?.value;
      if (settings?.hardwareDecoding ?? true) {
        await native.setProperty('hwdec', 'auto');
      } else {
        await native.setProperty('hwdec', 'no');
      }

      // 1. Performance tuning & Anti-Looping
      await native.setProperty('cache', 'yes');

      final isLivePattern =
          _isLiveStream(stream.url) ||
          _item.contentType == MultimediaContentType.livestream;
      if (kDebugMode) {
        debugPrint(
          'Stream Type (isLivePattern): $isLivePattern, URL: ${stream.url}',
        );
      }
      if (isLivePattern) {
        // Live TV: small buffer to absorb network jitter, not the large VOD buffer
        await native.setProperty('demuxer-readahead-secs', '8');
        await native.setProperty('cache-secs', '8');
        await native.setProperty('cache', 'yes');
        await native.setProperty('cache-pause-initial', 'yes');
        await native.setProperty('cache-pause-wait', '2');

        // Network
        await native.setProperty('network-timeout', '30');
        await native.setProperty('tls-verify', 'no');

        // Reconnect
        await native.setProperty(
          'stream-lavf-o',
          'reconnect_on_network_error=1,reconnect_delay_max=5,reconnect_on_eof=1,reconnect_streamed=1',
        );

        // HLS demuxer
        await native.setProperty('demuxer-lavf-o', 'seg_max_retry=5');

        // Playback
        await native.setProperty('framedrop', 'decoder');
        await native.setProperty('hr-seek-framedrop', 'yes');
        await native.setProperty('hwdec', 'auto-safe');

        // H.264 resilience: wait for clean keyframe after reconnect
        await native.setProperty('vd-lavc-skiploopfilter', 'nonkey');
        await native.setProperty('vd-lavc-skipframe', 'nonref');

        if (kDebugMode) {
          _player.stream.log.listen((log) {
            debugPrint('[MPV] ${log.level}: ${log.text}');
          });
        }
      } else {
        final settings = ref.read(playerSettingsProvider).asData?.value;
        final readahead = settings?.readaheadSeconds ?? 180;
        await native.setProperty('demuxer-readahead-secs', '$readahead');
        await native.setProperty('cache-secs', '$readahead');
        await native.setProperty('cache', 'yes');
      }

      // Adaptive demuxer cache based on device profile
      final profile = ref.read(deviceProfileProvider).asData?.value;
      String cacheSize = "512MiB"; // Default
      if (profile != null) {
        if (profile.isTv) {
          cacheSize = "128MiB"; // Less RAM on TVs
        } else if (profile.isDesktopOS || profile.isTablet) {
          cacheSize = "1GiB"; // More RAM on Desktop/Tablets
        }
      }

      await native.setProperty('demuxer-max-bytes', cacheSize);
      // Allow seeking back without re-fetching — proportional to device RAM
      final backCacheSize = profile?.isTv == true
          ? '64MiB'
          : (profile?.isDesktopOS == true || profile?.isTablet == true)
          ? '256MiB'
          : '128MiB';
      await native.setProperty('demuxer-max-back-bytes', backCacheSize);

      // 2. Resolve ClearKey Hex Keys
      String? keyHex = stream.drmKey;

      if (keyHex == null && stream.licenseUrl != null) {
        final extractedKeys = await _extractKeysFromLicenseUrl(
          stream.licenseUrl!,
          headers: stream.headers,
        );
        if (extractedKeys != null) {
          keyHex = extractedKeys['key'];
        }
      }

      if (keyHex != null) {
        // FFmpeg's DASH demuxer natively expects cenc_decryption_key.
        // It's usually the 32-character hex KEY.
        if (kDebugMode) {
          debugPrint(
            '[DRM] Injecting cenc_decryption_key via demuxer-lavf-o: $keyHex',
          );
        }

        if (!_shouldUseVideoView) {
          await native.setProperty(
            'demuxer-lavf-o',
            'cenc_decryption_key=$keyHex',
          );
        } else {
          // If using VideoView on Android, we'd pass DRM keys to the native side here.
        }
      }

      try {
        final tempDir = await getTemporaryDirectory();
        final cookieFile = File('${tempDir.path}/mpv_cookies.txt');
        if (!await cookieFile.exists()) {
          await cookieFile.create();
        }
        await native.setProperty('cookies-file', cookieFile.path);
        await native.setProperty('cookies-file-access', 'read+write');
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to set cookies-file: $e');
      }
    }
  }

  /// Fetches a ClearKey license from [licenseUrl] and returns the FIRST
  /// kid and key found as a map: {'kid': '...', 'key': '...'} in hex format.
  /// If the response is not parseable, returns null.
  Future<Map<String, String>?> _extractKeysFromLicenseUrl(
    String licenseUrl, {
    Map<String, String>? headers,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[DRM] Fetching ClearKey license from $licenseUrl');
      }
      final response = await http.get(Uri.parse(licenseUrl), headers: headers);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint('[DRM] License server returned ${response.statusCode}');
        }
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final keys = body['keys'] as List<dynamic>?;
      if (keys == null || keys.isEmpty) {
        if (kDebugMode) debugPrint('[DRM] No keys array in license response');
        return null;
      }

      // MPV's libdash only supports a single kid:key pair reliably via Laurl redirect.
      for (final entry in keys) {
        final kid = entry['kid'] as String?;
        final k = entry['k'] as String?;
        if (kid == null || k == null) continue;

        // Base64url → hex conversion.
        final kidHex = _base64UrlToHex(kid);
        final keyHex = _base64UrlToHex(k);
        if (kidHex != null && keyHex != null) {
          return {'kid': kidHex, 'key': keyHex};
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[DRM] Error fetching/parsing license: $e');
      return null;
    }
  }

  /// Converts a Base64url-encoded string to a lowercase hex string.
  String? _base64UrlToHex(String base64url) {
    try {
      // Add padding if needed.
      String padded = base64url;
      final rem = padded.length % 4;
      if (rem == 2) padded += '==';
      if (rem == 3) padded += '=';
      final bytes = base64Url.decode(padded);
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DRM] base64url decode failed for "$base64url": $e');
      }
      return null;
    }
  }

  bool _isLiveStream(String url) {
    if (url.isEmpty) return false;

    // Items explicitly marked as livestream in provider metadata
    if (_item.contentType == MultimediaContentType.livestream) return true;

    final lower = url.toLowerCase();

    // Torrents and local files are definitely VOD
    if (lower.startsWith('magnet:') ||
        lower.endsWith('.torrent') ||
        lower.startsWith('/')) {
      return false;
    }

    // Live protocols
    if (lower.startsWith('rtmp://') ||
        lower.startsWith('rtsp://') ||
        lower.startsWith('mms://') ||
        lower.startsWith('udp://') ||
        lower.startsWith('rtp://')) {
      return true;
    }

    // IPTV specific path/query patterns
    if (lower.contains('/live/') ||
        lower.contains('/iptv/') ||
        lower.contains('stream.m3u8') ||
        lower.contains('chunklist')) {
      return true;
    }

    // Xtream Codes API patterns
    if (lower.contains('type=m3u8') || lower.contains('output=m3u8')) {
      return true;
    }

    // Default to VOD for bandwidth protection
    return false;
  }

  Future<void> _safeSeekTo(int position) async {
    if (position <= 0) return;

    // ExoPlayer path: seek directly; no media_kit stream to wait on.
    if (state.useExoPlayer && _videoViewController != null) {
      try {
        _videoViewController!.seekTo(position);
      } catch (e) {
        if (kDebugMode) debugPrint("ExoPlayer seek failed: $e");
      }
      return;
    }

    // media_kit path: wait for duration to be known before seeking.
    try {
      var duration = _player.state.duration;
      if (duration == Duration.zero) {
        duration = await _player.stream.duration
            .firstWhere((d) => d != Duration.zero)
            .timeout(const Duration(seconds: 8));
      }

      final maxMs = duration.inMilliseconds;
      if (maxMs <= 0) return;

      final targetMs = position.clamp(0, maxMs);
      await _player.seek(Duration(milliseconds: targetMs));
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint("Timeout waiting for duration: $e");
      }

      // Best-effort fallback: some streams can seek before duration is reported.
      try {
        await _player.seek(Duration(milliseconds: position));
      } catch (seekError) {
        if (kDebugMode) {
          debugPrint("Fallback seek failed: $seekError");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Seek failed: $e");
      }
    }
  }

  Future<void> _flushPendingResumeSeek() async {
    final pos = _pendingResumeSeekPosition;
    if (pos == null || pos <= 0 || _isApplyingPendingResumeSeek) return;

    _isApplyingPendingResumeSeek = true;
    try {
      await _safeSeekTo(pos);
      _pendingResumeSeekPosition = null;
    } finally {
      _isApplyingPendingResumeSeek = false;
    }
  }

  Future<void> setPlaybackSpeed(double rate) async {
    await _player.setRate(rate);
    state = state.copyWith(playbackSpeed: rate);
  }

  Future<void> setSubtitleDelay(double seconds) async {
    final native = _player.platform;
    if (native is NativePlayer) {
      await native.setProperty('sub-delay', seconds.toString());
      state = state.copyWith(subtitleDelay: seconds);
    }
  }

  Future<void> applySubtitleSettings() async {
    final native = _player.platform;
    if (native is NativePlayer) {
      final settings =
          ref.read(playerSettingsProvider).asData?.value ??
          const PlayerSettings();

      // MPV sub properties
      await native.setProperty(
        'sub-font-size',
        settings.subtitleSize.toString(),
      );
      await native.setProperty(
        'sub-pos',
        settings.subtitlePosition.round().toString(),
      );

      // Colors are in MPV hex format (e.g. #RRGGBB or #AARRGGBB)
      String colorToMpvHex(int color, [double opacity = 1.0]) {
        final alpha = (opacity * 255).toInt().toRadixString(16).padLeft(2, '0');
        final rgb = color.toRadixString(16).padLeft(8, '0').substring(2);
        return '#$alpha$rgb';
      }

      await native.setProperty(
        'sub-color',
        colorToMpvHex(settings.subtitleColor),
      );
      if (settings.subtitleBackgroundColor != 0x00000000) {
        await native.setProperty(
          'sub-back-color',
          colorToMpvHex(
            settings.subtitleBackgroundColor,
            settings.subtitleBackgroundOpacity,
          ),
        );
      } else {
        await native.setProperty('sub-back-color', '#00000000');
      }
    }
  }

  Future<void> loadExternalSubtitleFile({String? filePath}) async {
    String? path = filePath;
    if (path == null) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
      );
      if (result != null && result.files.single.path != null) {
        path = result.files.single.path!;
      }
    }

    if (path != null) {
      final player = _player;
      final ext = p.extension(path).toLowerCase().replaceAll('.', '');

      // Load track into media_kit
      await player.setSubtitleTrack(
        SubtitleTrack.uri(path, title: "External ($ext)", language: "und"),
      );

      // Add to local state
      final newSub = SubtitleFile(
        url: path,
        label: "External ($ext)",
        lang: "und",
      );

      state = state.copyWith(
        externalSubtitles: [...state.externalSubtitles, newSub],
      );
    }
  }
}

final playerControllerProvider =
    NotifierProvider.autoDispose<PlayerController, PlayerState>(
      PlayerController.new,
    );
