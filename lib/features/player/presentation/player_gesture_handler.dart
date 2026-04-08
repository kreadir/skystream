import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../settings/presentation/player_settings_provider.dart';

class PlayerGestureHandler extends ChangeNotifier {
  final Future<PlayerSettings> Function() getSettings;
  final bool isTv;
  final bool isDesktop;

  // State from player
  Duration Function() getDuration;
  Duration Function() getPosition;
  bool Function() canSeek;
  double Function() getMaxVolumeLevel;

  // Callbacks to interact with UI
  final VoidCallback onInteraction;
  final VoidCallback onHideControls;
  final Future<void> Function(Duration) onSeekRelative;
  final Future<void> Function(Duration) onSeekTo;
  final Future<double> Function() getVolumeLevel;
  final Future<double> Function(double value) setVolumeLevel;
  final Future<double> Function(double step) changeVolumeLevel;
  final Future<double> Function() toggleMuteLevel;
  final void Function(bool isLeft, Offset tapPos, int seekSeconds)
  onDoubleTapAnimationStart;

  // Local State
  PlayerGesture? currentGesture;
  bool showOSD = false;
  IconData osdIcon = Icons.settings;
  double? osdValue;
  String osdLabel = "";
  Alignment osdAlignment = Alignment.center;
  Duration? swipeSeekValue;

  double _boostLevel = 1.0;
  Timer? _osdTimer;
  PlayerSettings? _cachedSettings;

  bool get supportsVolumeBoost => getMaxVolumeLevel() > 1.0;

  PlayerGestureHandler({
    required this.getSettings,
    required this.isTv,
    required this.isDesktop,
    required this.getDuration,
    required this.getPosition,
    required this.canSeek,
    required this.getMaxVolumeLevel,
    required this.onInteraction,
    required this.onHideControls,
    required this.onSeekRelative,
    required this.onSeekTo,
    required this.getVolumeLevel,
    required this.setVolumeLevel,
    required this.changeVolumeLevel,
    required this.toggleMuteLevel,
    required this.onDoubleTapAnimationStart,
  });

  @override
  void dispose() {
    _osdTimer?.cancel();
    super.dispose();
  }

  void _triggerOSDTimer() {
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 1), () {
      showOSD = false;
      notifyListeners();
    });
  }

  /// Dismiss the OSD overlay (e.g. on tap). Call [notifyListeners] so listeners can rebuild.
  void dismissOSD() {
    showOSD = false;
    notifyListeners();
  }

  void showToast(String message, IconData icon) {
    showOSD = true;
    osdIcon = icon;
    osdLabel = message;
    osdValue = null;
    osdAlignment = Alignment.bottomCenter;
    notifyListeners();

    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 2), () {
      showOSD = false;
      notifyListeners();
    });
  }

  // Pixels from each edge that are reserved for system gestures.
  // Touches starting inside these zones are ignored to avoid conflicts with
  // Android/iOS swipe-from-edge system gestures (back, notification shade, etc.).
  static const double _edgeExclusionHorizontal = 48.0; // left/right
  static const double _edgeExclusionTop = 48.0; // top (notification shade)

  Future<void> handleDragStart(
    DragStartDetails details,
    double screenWidth,
    double screenHeight,
  ) async {
    if (isTv || isDesktop) return;

    final x = details.globalPosition.dx;
    final y = details.globalPosition.dy;

    // Ignore touches near the left/right edges (system back gesture on Android)
    // or near the top edge (notification shade pull-down on Android/iOS).
    if (x < _edgeExclusionHorizontal ||
        x > screenWidth - _edgeExclusionHorizontal ||
        y < _edgeExclusionTop) {
      return;
    }
    // Use cached settings to avoid async gap on every swipe start.
    // Refresh the cache in the background after each use.
    final settings = _cachedSettings ?? await getSettings();
    _cachedSettings ??= settings;
    getSettings().then((s) => _cachedSettings = s);

    PlayerGesture type = PlayerGesture.none;
    if (x < screenWidth / 2) {
      type = settings.leftGesture;
      osdAlignment = Alignment.centerRight; // Opposite side
    } else {
      type = settings.rightGesture;
      osdAlignment = Alignment.centerLeft; // Opposite side
    }

    if (type == PlayerGesture.none) return;

    currentGesture = type;

    double startVal = 0.5;
    if (type == PlayerGesture.brightness) {
      try {
        startVal = await ScreenBrightness().application;
      } catch (e) {
        startVal = 0.5;
      }
    } else {
      startVal = await getVolumeLevel();
      _boostLevel = supportsVolumeBoost && startVal > 1.0 ? startVal : 1.0;
    }

    showOSD = true;
    osdIcon = _getIconForValue(type, startVal);
    osdValue = startVal;
    osdLabel = type == PlayerGesture.brightness ? "Brightness" : "Volume";
    notifyListeners();

    _osdTimer?.cancel();
  }

  void handleDragUpdate(DragUpdateDetails details) {
    if (currentGesture == null || currentGesture == PlayerGesture.none) return;

    final delta = -details.primaryDelta! / 300;

    final double min = (currentGesture == PlayerGesture.brightness)
        ? -0.05
        : 0.0;
    final double max = (currentGesture == PlayerGesture.brightness)
        ? 1.0
        : getMaxVolumeLevel();

    final double newVal = ((osdValue ?? 0.0) + delta).clamp(min, max);

    osdValue = newVal;
    osdIcon = _getIconForValue(currentGesture!, newVal);

    if (currentGesture == PlayerGesture.brightness) {
      if (newVal <= 0.0) {
        ScreenBrightness().resetApplicationScreenBrightness();
        osdLabel = "Auto";
      } else {
        ScreenBrightness().setApplicationScreenBrightness(newVal);
        osdLabel = "Brightness";
      }
    } else {
      _boostLevel = supportsVolumeBoost && newVal > 1.0 ? newVal : 1.0;
      unawaited(setVolumeLevel(newVal));
    }
    notifyListeners();
  }

  void handleDragEnd(DragEndDetails details) {
    currentGesture = null;
    _triggerOSDTimer();
  }

  Future<void> handleHorizontalDragStart(
    DragStartDetails details,
    bool isControlsVisible,
    double screenWidth,
    double screenHeight,
    double bottomPadding,
  ) async {
    if (getDuration() == Duration.zero || !canSeek()) return;

    final swipeSettings = await getSettings();
    if (!swipeSettings.swipeSeekEnabled) return;

    if (isTv || isDesktop) return;

    // Ignore touches near left/right edges (Android system back gesture).
    final x = details.globalPosition.dx;
    if (x < _edgeExclusionHorizontal ||
        x > screenWidth - _edgeExclusionHorizontal) {
      return;
    }

    if (isControlsVisible) {
      if (details.globalPosition.dy > (screenHeight - 100 - bottomPadding)) {
        return; // Avoid conflict with seek bar
      }
    }

    swipeSeekValue = getPosition();
    notifyListeners();
  }

  void handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (swipeSeekValue == null) return;

    final delta = details.primaryDelta ?? 0;
    final newMs = (swipeSeekValue!.inMilliseconds + (delta * 200)).toInt();
    final clamped = newMs.clamp(0, getDuration().inMilliseconds);

    swipeSeekValue = Duration(milliseconds: clamped);
    notifyListeners();
  }

  void handleHorizontalDragEnd(DragEndDetails details) {
    if (swipeSeekValue == null) return;
    final target = swipeSeekValue!;
    swipeSeekValue = null;
    notifyListeners();
    unawaited(onSeekTo(target));
  }

  Future<void> handleDoubleTap(Offset tapPosition, double screenWidth) async {
    if (getDuration() == Duration.zero) return;

    final settings = await getSettings();
    if (!settings.doubleTapEnabled) return;

    final isLeft = tapPosition.dx < screenWidth / 2;
    final seconds = settings.seekDuration;

    onDoubleTapAnimationStart(isLeft, tapPosition, seconds);

    if (isLeft) {
      unawaited(onSeekRelative(Duration(seconds: -seconds)));
    } else {
      unawaited(onSeekRelative(Duration(seconds: seconds)));
    }
  }

  Future<void> toggleMute() async {
    final value = await toggleMuteLevel();
    if (value <= 0) {
      showToast("Mute", Icons.volume_off);
    } else {
      _showVolumeOsd(value);
    }
  }

  Future<void> changeVolume(double step) async {
    final value = await changeVolumeLevel(step);
    _showVolumeOsd(value);
  }

  void _showVolumeOsd(double value) {
    _boostLevel = supportsVolumeBoost && value > 1.0 ? value : 1.0;
    showOSD = true;
    osdIcon = _getIconForValue(PlayerGesture.volume, value);
    if (supportsVolumeBoost && _boostLevel > 1.0) {
      osdValue = _boostLevel;
      osdLabel = "Volume ${(_boostLevel * 100).toInt()}%";
    } else {
      osdValue = value;
      osdLabel = "Volume ${(value * 100).toInt()}%";
    }
    notifyListeners();
    _triggerOSDTimer();
  }

  IconData _getIconForValue(PlayerGesture type, double value) {
    if (type == PlayerGesture.brightness) {
      if (value <= 0.0) return Icons.brightness_auto;
      if (value < 0.3) return Icons.brightness_low;
      if (value < 0.7) return Icons.brightness_medium;
      return Icons.brightness_high;
    } else if (type == PlayerGesture.volume) {
      if (value <= 0.0) return Icons.volume_off;
      if (value < 0.3) return Icons.volume_mute;
      if (value < 0.7) return Icons.volume_down;
      if (!supportsVolumeBoost || value <= 1.0) return Icons.volume_up;
      return Icons.campaign;
    }
    return Icons.settings;
  }
}
