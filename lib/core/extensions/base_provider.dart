import '../domain/entity/multimedia_item.dart';

enum ProviderType { movie, series, anime, iptv, other }

abstract class SkyStreamProvider {
  String get id;
  String get name;
  String get mainUrl;
  String get version;
  String get lang;
  Set<ProviderType> get supportedTypes;
  bool get hasSearch => true;
  bool get isDebug => id.endsWith('.debug');

  // Key methods providers must implement
  Future<List<MultimediaItem>> search(String query);
  // Returns categorized content (Section Name -> Items)
  Future<Map<String, List<MultimediaItem>>> getHome();
  Future<MultimediaItem> getDetails(String url);
  
  // Returns list of video streams (urls)
  Future<List<StreamResult>> loadStreams(String url);
}

class StreamResult {
  final String url;
  final String quality; // 720p, 1080p, etc
  final Map<String, String>? headers;
  final List<SubtitleFile>? subtitles;

  const StreamResult({required this.url, this.quality = 'Auto', this.headers, this.subtitles});
}

class SubtitleFile {
  final String url;
  final String label;
  final String? lang;

  const SubtitleFile({required this.url, required this.label, this.lang});
  
  factory SubtitleFile.fromJson(Map<String, dynamic> json) {
      return SubtitleFile(
          url: json['url'],
          label: json['label'] ?? 'Unknown',
          lang: json['lang']
      );
  }
}
