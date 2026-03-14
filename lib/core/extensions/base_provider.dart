import '../domain/entity/multimedia_item.dart';

enum ProviderType { movie, series, anime, iptv, other }

abstract class SkyStreamProvider {
  /// Unique Package Name (from plugin.json)
  String get packageName;

  /// Display Name
  String get name;
  String get mainUrl;
  String get version;
  List<String> get languages;
  Set<ProviderType> get supportedTypes;
  bool get hasSearch => true;
  bool get isDebug => packageName.endsWith('.debug');

  // Key methods providers must implement
  Future<List<MultimediaItem>> search(String query);
  // Returns categorized content (Section Name -> Items)
  Future<Map<String, List<MultimediaItem>>> getHome();
  Future<MultimediaItem> getDetails(String url);

  // Returns list of video streams (urls)
  Future<List<StreamResult>> loadStreams(String url);
}
