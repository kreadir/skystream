import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../shared/widgets/custom_widgets.dart';

/// A self-contained progress bar widget that uses StreamBuilder to avoid
/// rebuilding the parent widget on every position update.
/// This is a StatefulWidget to handle drag state internally.
class PlayerProgressBar extends StatefulWidget {
  final Player player;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  const PlayerProgressBar({
    super.key,
    required this.player,
    this.onSeekStart,
    this.onSeekEnd,
  });

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  double? _dragValue;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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

            // Use drag value if dragging, otherwise use stream position
            final displayValue = _dragValue ?? positionMs;
            final displayDuration = _dragValue != null
                ? Duration(milliseconds: _dragValue!.toInt())
                : position;

            return Row(
              children: [
                const SizedBox(width: 12),
                // Current position text
                SizedBox(
                  width: duration.inHours > 0 ? 65 : 45,
                  child: Text(
                    _formatDuration(displayDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                // Slider
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
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
                      step: 5000, // 5 seconds step
                      onChanged: (val) {
                        setState(() {
                          _dragValue = val;
                        });
                      },
                      onChangeStart: (val) {
                        widget.onSeekStart?.call();
                        setState(() {
                          _dragValue = val;
                        });
                      },
                      onChangeEnd: (val) {
                        widget.player.seek(Duration(milliseconds: val.toInt()));
                        widget.onSeekEnd?.call();
                        setState(() {
                          _dragValue = null;
                        });
                      },
                    ),
                  ),
                ),
                // Duration text
                SizedBox(
                  width: duration.inHours > 0 ? 65 : 45,
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
          },
        );
      },
    );
  }
}

/// A play/pause button that uses StreamBuilder to avoid parent rebuilds.
class PlayerPlayPauseButton extends StatelessWidget {
  final Player player;
  final bool isLoading;
  final bool isTv;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  const PlayerPlayPauseButton({
    super.key,
    required this.player,
    this.isLoading = false,
    this.isTv = false,
    this.focusNode,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (context, bufferingSnapshot) {
        final isBuffering = bufferingSnapshot.data ?? false;

        return StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

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
                child: (isBuffering || isLoading)
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
          },
        );
      },
    );
  }
}

/// A buffering indicator that only rebuilds when buffering state changes.
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
    return StreamBuilder<bool>(
      stream: player.stream.buffering,
      initialData: player.state.buffering,
      builder: (context, snapshot) {
        final isBuffering = snapshot.data ?? false;

        if (!isBuffering && !isLoading) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: !isVisible ? 1.0 : 0.0,
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
