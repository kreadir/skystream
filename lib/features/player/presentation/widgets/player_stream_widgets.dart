import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_view/video_view.dart' as vv;
import '../player_controller.dart';
import '../../../../shared/widgets/custom_widgets.dart';

/// A self-contained progress bar widget that uses StreamBuilder to avoid
/// rebuilding the parent widget on every position update.
class PlayerProgressBar extends ConsumerStatefulWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const PlayerProgressBar({
    super.key,
    required this.player,
    this.videoViewController,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  ConsumerState<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends ConsumerState<PlayerProgressBar> {
  double? _dragValue;
  int _vvPositionMs = 0;
  int _vvDurationMs = 0;

  @override
  void initState() {
    super.initState();
    widget.videoViewController?.position.addListener(_onVvPosition);
    widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
  }

  @override
  void didUpdateWidget(PlayerProgressBar old) {
    super.didUpdateWidget(old);
    if (old.videoViewController != widget.videoViewController) {
      old.videoViewController?.position.removeListener(_onVvPosition);
      old.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
      widget.videoViewController?.position.addListener(_onVvPosition);
      widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
    }
  }

  void _onVvPosition() {
    final ms = widget.videoViewController?.position.value ?? 0;
    if (mounted) setState(() => _vvPositionMs = ms);
  }

  void _onVvMediaInfo() {
    final ms = widget.videoViewController?.mediaInfo.value?.duration ?? 0;
    if (mounted) setState(() => _vvDurationMs = ms);
  }

  @override
  void dispose() {
    widget.videoViewController?.position.removeListener(_onVvPosition);
    widget.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final absDuration = duration.abs();
    final hours = absDuration.inHours;
    final minutes = absDuration.inMinutes.remainder(60);
    final seconds = absDuration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final useExoPlayer = ref.watch(
      playerControllerProvider.select((s) => s.useExoPlayer),
    );

    if (useExoPlayer && widget.videoViewController != null) {
      return _buildVideoViewBar();
    }
    return _buildMediaKitBar();
  }

  Widget _buildVideoViewBar() {
    final playerState = ref.watch(playerControllerProvider);
    final durationMs = _vvDurationMs.toDouble();
    final positionMs = _vvPositionMs.toDouble();
    final displayValue = _dragValue ?? positionMs;
    final displayDuration = Duration(
      milliseconds: (_dragValue ?? positionMs).toInt(),
    );
    final duration = Duration(milliseconds: _vvDurationMs);

    final isLive = playerState.isLive;

    return _buildRow(
      duration: duration,
      durationMs: durationMs,
      displayValue: displayValue,
      displayDuration: displayDuration,
      bufferWidget: null,
      onSeekEnd: (val) => widget.videoViewController!.seekTo(val.toInt()),
      isLive: isLive,
    );
  }

  Widget _buildMediaKitBar() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final durationMs = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: widget.player.stream.position,
          initialData: widget.player.state.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final positionMs = position.inMilliseconds.toDouble();
            final displayValue = _dragValue ?? positionMs;
            final displayDuration = _dragValue != null
                ? Duration(milliseconds: _dragValue!.toInt())
                : position;

            final bufferWidget = durationMs > 0
                ? StreamBuilder<Duration>(
                    stream: widget.player.stream.buffer,
                    initialData: widget.player.state.buffer,
                    builder: (context, bufferSnapshot) {
                      final bufferMs = (bufferSnapshot.data ?? Duration.zero)
                          .inMilliseconds
                          .toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: LinearProgressIndicator(
                          value: (bufferMs / durationMs).clamp(0, 1),
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.25),
                          ),
                          minHeight: 4,
                        ),
                      );
                    },
                  )
                : null;

            return _buildRow(
              duration: duration,
              durationMs: durationMs,
              displayValue: displayValue,
              displayDuration: displayDuration,
              bufferWidget: bufferWidget,
              onSeekEnd: (val) =>
                  widget.player.seek(Duration(milliseconds: val.toInt())),
              isLive: ref.watch(playerControllerProvider).isLive,
            );
          },
        );
      },
    );
  }

  Widget _buildRow({
    required Duration duration,
    required double durationMs,
    required double displayValue,
    required Duration displayDuration,
    required Widget? bufferWidget,
    required void Function(double val) onSeekEnd,
    bool isLive = false,
  }) {
    return Row(
      children: [
        const SizedBox(width: 12),
        // Left Side: Current Position
        SizedBox(
          width: duration.inHours > 0 ? 70 : 50,
          child: Text(
            _formatDuration(displayDuration),
            style: const TextStyle(
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (bufferWidget != null) bufferWidget,
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.2),
                ),
                child: CustomSlider(
                  value: displayValue.clamp(
                    0,
                    durationMs > 0 ? durationMs : 1.0,
                  ),
                  min: 0.0,
                  max: durationMs > 0 ? durationMs : 1.0,
                  step: 5000,
                  onChanged: (val) => setState(() => _dragValue = val),
                  onChangeStart: (val) {
                    widget.onSeekStart?.call();
                    setState(() => _dragValue = val);
                  },
                  onChangeEnd: (val) {
                    onSeekEnd(val);
                    widget.onSeekEnd?.call();
                    setState(() => _dragValue = null);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (isLive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.withAlpha(120), width: 1),
            ),
            child: const Text(
              "🔴  LIVE",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          )
        else
          SizedBox(
            width: duration.inHours > 0 ? 70 : 50,
            child: Text(
              _formatDuration(duration),
              style: const TextStyle(
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.left,
            ),
          ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class PlayerPlayPauseButton extends StatelessWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final bool isLoading;
  final bool isTv;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  const PlayerPlayPauseButton({
    super.key,
    required this.player,
    this.videoViewController,
    this.isLoading = false,
    this.isTv = false,
    this.focusNode,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isBuffering = ref.watch(
          playerControllerProvider.select((s) => s.isBuffering),
        );
        final useExoPlayer = ref.watch(
          playerControllerProvider.select((s) => s.useExoPlayer),
        );

        if (useExoPlayer && videoViewController != null) {
          return ListenableBuilder(
            listenable: videoViewController!.playbackState,
            builder: (context, _) {
              final isPlaying =
                  videoViewController!.playbackState.value ==
                  vv.VideoControllerPlaybackState.playing;
              return _buildButton(
                isPlaying: isPlaying,
                isSpinning:
                    isBuffering, // Only show spinner for buffering in Full UI
              );
            },
          );
        }

        return StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;
            return _buildButton(
              isPlaying: isPlaying,
              isSpinning:
                  isBuffering, // Only show spinner for buffering in Full UI
            );
          },
        );
      },
    );
  }

  Widget _buildButton({required bool isPlaying, required bool isSpinning}) {
    return CustomButton(
      showFocusHighlight: isTv,
      autofocus: true,
      focusNode: focusNode,
      onPressed: onPressed ?? () => player.playOrPause(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: isSpinning
            ? const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 64,
              ),
      ),
    );
  }
}

class PlayerBufferingIndicator extends StatelessWidget {
  final Player player;
  final bool isLoading;
  final bool isVisible;

  const PlayerBufferingIndicator({
    super.key,
    required this.player,
    this.isLoading = false,
    this.isVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isBuffering = ref.watch(
          playerControllerProvider.select((s) => s.isBuffering),
        );

        if (!isBuffering) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
