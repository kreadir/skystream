import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayerGesture { brightness, volume, none }

class PlayerSettings {
  final PlayerGesture leftGesture;
  final PlayerGesture rightGesture;
  final bool doubleTapEnabled;
  final bool swipeSeekEnabled;
  final int seekDuration;
  final String defaultResizeMode;
  final double subtitleSize;
  final int subtitleColor;
  final int subtitleBackgroundColor;

  const PlayerSettings({
    this.leftGesture = PlayerGesture.brightness,
    this.rightGesture = PlayerGesture.volume,
    this.doubleTapEnabled = true,
    this.swipeSeekEnabled = true,
    this.seekDuration = 10,
    this.defaultResizeMode = 'Fit',
    this.subtitleSize = 22.0,
    this.subtitleColor = 0xFFFFFFFF, // White
    this.subtitleBackgroundColor = 0x00000000, // Transparent
  });

  PlayerSettings copyWith({
    PlayerGesture? leftGesture, 
    PlayerGesture? rightGesture,
    bool? doubleTapEnabled,
    bool? swipeSeekEnabled,
    int? seekDuration,
    String? defaultResizeMode,
    double? subtitleSize,
    int? subtitleColor,
    int? subtitleBackgroundColor,
  }) {
    return PlayerSettings(
      leftGesture: leftGesture ?? this.leftGesture,
      rightGesture: rightGesture ?? this.rightGesture,
      doubleTapEnabled: doubleTapEnabled ?? this.doubleTapEnabled,
      swipeSeekEnabled: swipeSeekEnabled ?? this.swipeSeekEnabled,
      seekDuration: seekDuration ?? this.seekDuration,
      defaultResizeMode: defaultResizeMode ?? this.defaultResizeMode,
      subtitleSize: subtitleSize ?? this.subtitleSize,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      subtitleBackgroundColor: subtitleBackgroundColor ?? this.subtitleBackgroundColor,
    );
  }
}

class PlayerSettingsNotifier extends Notifier<PlayerSettings> {
  @override
  PlayerSettings build() {
    _load();
    return const PlayerSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final l = prefs.getString('player_gesture_left') ?? 'brightness';
    final r = prefs.getString('player_gesture_right') ?? 'volume';
    final dt = prefs.getBool('player_double_tap') ?? true;
    final dur = prefs.getInt('player_seek_duration') ?? 10;
    final resize = prefs.getString('player_default_resize') ?? 'Fit';
    final subSize = prefs.getDouble('player_sub_size') ?? 22.0;
    final subColor = prefs.getInt('player_sub_color') ?? 0xFFFFFFFF;
    final subBg = prefs.getInt('player_sub_bg') ?? 0x00000000;
    
    state = PlayerSettings(
      leftGesture: _parse(l),
      rightGesture: _parse(r),
      doubleTapEnabled: dt,
      swipeSeekEnabled: prefs.getBool('player_swipe_seek') ?? true,
      seekDuration: dur,
      defaultResizeMode: resize,
      subtitleSize: subSize,
      subtitleColor: subColor,
      subtitleBackgroundColor: subBg,
    );
  }

  Future<void> setLeftGesture(PlayerGesture g) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_gesture_left', g.name);
    state = state.copyWith(leftGesture: g);
  }

  Future<void> setRightGesture(PlayerGesture g) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_gesture_right', g.name);
    state = state.copyWith(rightGesture: g);
  }

  Future<void> setDoubleTapEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('player_double_tap', val);
    state = state.copyWith(doubleTapEnabled: val);
  }

  Future<void> setSwipeSeekEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('player_swipe_seek', val);
    state = state.copyWith(swipeSeekEnabled: val);
  }

  Future<void> setSeekDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('player_seek_duration', seconds);
    state = state.copyWith(seekDuration: seconds);
  }

  Future<void> setDefaultResizeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_default_resize', mode);
    state = state.copyWith(defaultResizeMode: mode);
  }

  Future<void> setSubtitleSettings(double size, int color, int bg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('player_sub_size', size);
    await prefs.setInt('player_sub_color', color);
    await prefs.setInt('player_sub_bg', bg);
    state = state.copyWith(subtitleSize: size, subtitleColor: color, subtitleBackgroundColor: bg);
  }

  PlayerGesture _parse(String s) {
    return PlayerGesture.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PlayerGesture.none,
    );
  }
}

final playerSettingsProvider = NotifierProvider<PlayerSettingsNotifier, PlayerSettings>(PlayerSettingsNotifier.new);
