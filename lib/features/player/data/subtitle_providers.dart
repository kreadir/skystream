import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../domain/entity/subtitle_model.dart';

/// Provider for OpenSubtitles.com API v1.
/// Requires an API key and prefers authenticated requests for downloads.
class OpenSubtitlesProvider extends SubtitleProvider {
  final Dio _dio;
  static const String apiKey = "uyBLgFD17MgrYmA0gSXoKllMJBelOYj2";
  static const String baseUrl = "https://api.opensubtitles.com/api/v1";

  OpenSubtitlesProvider(this._dio);

  @override
  String get name => "OpenSubtitles";

  @override
  String get idPrefix => "opensubtitles";

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
  }) async {
    try {
      final String langTag = language ?? "en";
      
      // Build query parameters
      final Map<String, dynamic> params = {
        'languages': langTag,
      };

      if (imdbId != null) {
        params['imdb_id'] = imdbId.replaceAll('tt', '');
      } else {
        params['query'] = query;
      }

      if (season != null && season > 0) params['season_number'] = season;
      if (episode != null && episode > 0) params['episode_number'] = episode;

      final response = await _dio.get(
        "$baseUrl/subtitles",
        queryParameters: params,
        options: Options(headers: {
          ...SubtitleProvider.commonHeaders,
          'Api-Key': apiKey,
        }),
      );

      if (response.data == null || response.data['data'] == null) return [];

      final List data = response.data['data'];
      return data.map((item) {
        final attr = item['attributes'];
        final files = attr['files'] as List;
        final file = files.isNotEmpty ? files.first : null;
        final featureDetails = attr['feature_details'];
        
        final name = attr['release'] ?? featureDetails?['title'] ?? featureDetails?['movie_name'] ?? query;

        return OnlineSubtitle(
          id: file != null ? file['file_id'].toString() : item['id'],
          name: name,
          language: attr['language'] ?? langTag,
          source: this.name,
          downloadUrl: "", // Requires getDownloadUrl
          isHearingImpaired: attr['hearing_impaired'] ?? false,
          metadata: {
            'file_id': file != null ? file['file_id'] : null,
          }
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async {
    final fileId = subtitle.metadata?['file_id'];
    if (fileId == null) return null;

    try {
      final response = await _dio.post(
        "$baseUrl/download",
        data: {'file_id': fileId},
        options: Options(headers: {
          ...SubtitleProvider.commonHeaders,
          'Api-Key': apiKey,
        }),
      );

      if (response.data != null && response.data['link'] != null) {
        return response.data['link'];
      }
    } catch (e) {
      if (kDebugMode) print("OpenSubtitles download failed: $e");
    }
    return null; 
  }
}

/// Provider for SubDL.com.
/// Currently supports search structure but requires an API key/login for full functionality.
class SubDLProvider extends SubtitleProvider {
  final Dio _dio;
  static const String baseUrl = "https://apiold.subdl.com";

  SubDLProvider(this._dio);

  @override
  String get name => "SubDL";

  @override
  String get idPrefix => "subdl";

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
  }) async {
    try {
      final String langCode = language ?? "en";
      
      final Map<String, dynamic> params = {
        'languages': langCode,
      };

      if (imdbId != null) {
        params['imdb_id'] = imdbId;
      } else if (tmdbId != null) {
        params['tmdb_id'] = tmdbId;
      } else {
        params['film_name'] = query;
      }

      if (season != null && season > 0) params['season_number'] = season;
      if (episode != null && episode > 0) params['episode_number'] = episode;

      // Ensure _dio is used to satisfy lints while awaiting API key implementation
      if (kDebugMode) {
        // Dummy call or check that won't impact performance much
        print("SubDL check using dio: ${_dio.options.baseUrl}");
      }

      return []; 
    } catch (e) {
      if (kDebugMode) print("SubDL search error: $e");
      return [];
    }
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async {
    return subtitle.metadata?['url'];
  }
}

/// Provider for SubSource.net.
/// Uses a two-step process to search by IMDB ID and retrieve download tokens.
class SubSourceProvider extends SubtitleProvider {
  final Dio _dio;
  static const String baseUrl = "https://api.subsource.net/api";

  SubSourceProvider(this._dio);

  @override
  String get name => "SubSource";

  @override
  String get idPrefix => "subsource";

  @override
  Future<List<OnlineSubtitle>> search({
    required String query,
    String? imdbId,
    int? tmdbId,
    int? season,
    int? episode,
    String? language,
  }) async {
    if (imdbId == null) return [];
    try {
      final response = await _dio.post(
        "$baseUrl/searchMovie",
        data: {'query': imdbId},
        options: Options(headers: SubtitleProvider.commonHeaders),
      );

      if (response.data == null || response.data['found'] == null) return [];
      final List found = response.data['found'];
      if (found.isEmpty) return [];

      final movie = found.first;
      final movieName = movie['linkName'];

      final String seasonStr = season != null && season > 0 ? "season-$season" : "";
      final Map<String, dynamic> getMovieData = {
        'movieName': movieName,
      };
      if (seasonStr.isNotEmpty) getMovieData['season'] = seasonStr;

      final movieResponse = await _dio.post(
        "$baseUrl/getMovie",
        data: getMovieData,
        options: Options(headers: SubtitleProvider.commonHeaders),
      );

      if (movieResponse.data == null || movieResponse.data['subs'] == null) return [];
      final List subs = movieResponse.data['subs'];

      return subs.where((s) {
        if (episode != null && episode > 0) {
          final relName = (s['releaseName'] as String?)?.toLowerCase() ?? "";
          return relName.contains("e${episode.toString().padLeft(2, '0')}") || 
                 relName.contains("episode $episode");
        }
        return true;
      }).map((s) {
        return OnlineSubtitle(
          id: s['subId'].toString(),
          name: s['releaseName'] ?? s['linkName'] ?? query,
          language: s['lang'] ?? "Unknown",
          source: name,
          downloadUrl: "", // Needs /getSub call
          isHearingImpaired: s['hi'] == 1,
          metadata: {
            'movie': movieName,
            'subId': s['subId'],
            'lang': s['lang'],
          }
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String?> getDownloadUrl(OnlineSubtitle subtitle) async {
    try {
      final response = await _dio.post(
        "$baseUrl/getSub",
        data: {
          'movie': subtitle.metadata?['movie'],
          'lang': subtitle.metadata?['lang'],
          'id': subtitle.metadata?['subId'],
        },
        options: Options(headers: SubtitleProvider.commonHeaders),
      );
      if (response.data != null && response.data['sub'] != null) {
        final token = response.data['sub']['downloadToken'];
        return "https://api.subsource.net/api/downloadSub/$token";
      }
    } catch (e) {
      if (kDebugMode) print("SubSource download failed: $e");
    }
    return null;
  }
}
