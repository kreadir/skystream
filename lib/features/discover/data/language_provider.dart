import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final languageProvider = NotifierProvider<LanguageNotifier, String>(
  () => LanguageNotifier(),
);

class LanguageNotifier extends Notifier<String> {
  static const _kLanguageKey = 'selected_language';

  @override
  String build() {
    _loadSavedLanguage();
    return 'en-US';
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kLanguageKey);
      if (saved != null && saved != state) {
        state = saved;
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> setLanguage(String language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguageKey, language);
    } catch (_) {
      // Ignore errors
    }
  }
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;

  const LanguageOption(this.code, this.name, this.nativeName);
}

final languageListProvider = Provider<List<LanguageOption>>((ref) {
  return const [
    LanguageOption('en-US', 'English', 'English'),
    LanguageOption('hi-IN', 'Hindi', 'हिंदी'),
    LanguageOption('kn-IN', 'Kannada', 'ಕನ್ನಡ'),
    LanguageOption('ta-IN', 'Tamil', 'தமிழ்'),
    LanguageOption('te-IN', 'Telugu', 'తెలుగు'),
    LanguageOption('ml-IN', 'Malayalam', 'മലയാളം'),
    LanguageOption('bn-IN', 'Bengali', 'বাংলা'),
    LanguageOption('mr-IN', 'Marathi', 'मराठी'),
    LanguageOption('pa-IN', 'Punjabi', 'ਪੰਜਾਬੀ'),
    LanguageOption('es-ES', 'Spanish', 'Español'),
    LanguageOption('fr-FR', 'French', 'Français'),
    LanguageOption('de-DE', 'German', 'Deutsch'),
    LanguageOption('it-IT', 'Italian', 'Italiano'),
    LanguageOption('ja-JP', 'Japanese', '日本語'),
    LanguageOption('ko-KR', 'Korean', '한국어'),
    LanguageOption('ru-RU', 'Russian', 'Русский'),
  ];
});
