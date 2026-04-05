import 'dart:io';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/dio_client_provider.dart';
import '../data/subtitle_providers.dart';
import '../domain/entity/subtitle_model.dart';

const Map<String, String> subtitleLanguages = {
  'English': 'en',
  'Hindi': 'hi',
  'Bengali': 'bn',
  'Telugu': 'te',
  'Marathi': 'mr',
  'Tamil': 'ta',
  'Gujarati': 'gu',
  'Kannada': 'kn',
  'Malayalam': 'ml',
  'Punjabi': 'pa',
  'Arabic': 'ar',
  'Spanish': 'es',
  'French': 'fr',
  'German': 'de',
  'Russian': 'ru',
  'Chinese': 'zh',
  'Japanese': 'ja',
  'Korean': 'ko',
  'Turkish': 'tr',
  'Portuguese': 'pt',
  'Indonesian': 'id',
  'Vietnamese': 'vi',
};

class SubtitleSearchNotifier extends Notifier<AsyncValue<List<OnlineSubtitle>?>> {
  late List<SubtitleProvider> _providers;

  @override
  AsyncValue<List<OnlineSubtitle>?> build() {
    final dio = ref.read(dioClientProvider);
    _providers = [
      OpenSubtitlesProvider(dio),
      SubDLProvider(dio),
      SubSourceProvider(dio),
    ];
    return const AsyncData(null);
  }

  Future<void> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final List<OnlineSubtitle> allResults = [];
      
      final lang = language ?? ref.read(subtitleLanguageProvider);
      
      final searchTasks = _providers.map((pr) => pr.search(
        query: query,
        imdbId: imdbId,
        tmdbId: tmdbId,
        season: season,
        episode: episode,
        language: lang,
      ));

      final resultsList = await Future.wait(searchTasks);
      for (final results in resultsList) {
        allResults.addAll(results);
      }
      
      return allResults;
    });
  }

  Future<String?> downloadAndPrepare(OnlineSubtitle subtitle) async {
    final dio = ref.read(dioClientProvider);
    final provider = _providers.firstWhere((p) => p.name == subtitle.source);
    
    String? url = subtitle.downloadUrl;
    if (url.isEmpty) {
      url = await provider.getDownloadUrl(subtitle) ?? "";
    }
    
    if (url.isEmpty) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = p.join(tempDir.path, "temp_sub_${DateTime.now().millisecondsSinceEpoch}");
      
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: SubtitleProvider.commonHeaders,
        ),
      );

      final List<int> bytes = response.data;
      
      if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.isFile && (file.name.endsWith('.srt') || file.name.endsWith('.vtt'))) {
            final subFile = File(p.join(tempDir.path, file.name));
            await subFile.writeAsBytes(file.content as List<int>);
            return subFile.path;
          }
        }
      } else {
        final subFile = File("$savePath.srt");
        await subFile.writeAsBytes(bytes);
        return subFile.path;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

final subtitleSearchProvider = NotifierProvider.autoDispose<SubtitleSearchNotifier, AsyncValue<List<OnlineSubtitle>?>>(
  SubtitleSearchNotifier.new,
);

class SubtitleLanguageNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  void set(String lang) => state = lang;
}

final subtitleLanguageProvider = NotifierProvider<SubtitleLanguageNotifier, String>(
  SubtitleLanguageNotifier.new,
);
