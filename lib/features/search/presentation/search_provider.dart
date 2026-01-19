import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/domain/entity/multimedia_item.dart';

class ProviderSearchResult {
    final String providerId;
    final String providerName;
    final List<MultimediaItem> results;
    final String? error;
    
    ProviderSearchResult({required this.providerId, required this.providerName, required this.results, this.error});
}

// State for the search query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Async provider for search results
final searchResultsProvider = FutureProvider.autoDispose<List<ProviderSearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final manager = ref.read(extensionManagerProvider.notifier);
  final providers = manager.getAllProviders();
  
  if (query.length < 2) return [];

  // Create list of futures
  final futures = providers.map((provider) async {
      try {
          final rawResults = await provider.search(query);
          
          // Inject provider ID into items
          final results = rawResults.map((item) => MultimediaItem(
              title: item.title,
              url: item.url,
              posterUrl: item.posterUrl,
              bannerUrl: item.bannerUrl,
              description: item.description,
              isFolder: item.isFolder,
              episodes: item.episodes,
              provider: provider.id // Use ID
          )).toList();

          final filtered = results.where((item) {
              final titleLower = item.title.toLowerCase();
              final queryParts = query.toLowerCase().split(' ').where((s) => s.isNotEmpty);
              final titleParts = titleLower.split(' ').where((s) => s.isNotEmpty);
              
              for (final qPart in queryParts) {
                  bool foundPrefix = false;
                  for (final tPart in titleParts) {
                      if (tPart.startsWith(qPart)) {
                          foundPrefix = true;
                          break;
                      }
                  }
                  if (!foundPrefix) return false;
              }
              return true;
          }).toList();

          return ProviderSearchResult(providerId: provider.id, providerName: provider.name, results: filtered);
      } catch (e) {
          return ProviderSearchResult(providerId: provider.id, providerName: provider.name, results: [], error: e.toString());
      }
  }).toList();

  return await Future.wait(futures);
});
