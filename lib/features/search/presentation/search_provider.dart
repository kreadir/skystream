import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/domain/entity/multimedia_item.dart';

class ProviderSearchResult {
  final String providerId;
  final String providerName;
  final List<MultimediaItem> results;
  final String? error;

  ProviderSearchResult({
    required this.providerId,
    required this.providerName,
    required this.results,
    this.error,
  });
}

// State for the search query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// P8: StreamProvider for incremental search results - shows results as they arrive
final searchResultsProvider =
    StreamProvider.autoDispose<List<ProviderSearchResult>>((ref) async* {
      final query = ref.watch(searchQueryProvider);
      final manager = ref.read(extensionManagerProvider.notifier);
      final providers = manager.getAllProviders();

      if (query.length < 2) {
        yield [];
        return;
      }

      final results = <ProviderSearchResult>[];
      final queryLower = query.toLowerCase(); // Cache once, not per-item
      final queryParts = queryLower
          .split(' ')
          .where((s) => s.isNotEmpty)
          .toList();

      // Process each provider and yield incrementally
      for (final provider in providers) {
        try {
          final rawResults = await provider.search(query);

          // Inject provider ID into items
          final providerResults = rawResults
              .map(
                (item) => MultimediaItem(
                  title: item.title,
                  url: item.url,
                  posterUrl: item.posterUrl,
                  bannerUrl: item.bannerUrl,
                  description: item.description,
                  isFolder: item.isFolder,
                  episodes: item.episodes,
                  provider: provider.id,
                ),
              )
              .toList();

          // Filter with optimized logic
          final filtered = providerResults.where((item) {
            final titleLower = item.title.toLowerCase();
            final titleParts = titleLower
                .split(' ')
                .where((s) => s.isNotEmpty)
                .toList();

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

          results.add(
            ProviderSearchResult(
              providerId: provider.id,
              providerName: provider.name,
              results: filtered,
            ),
          );

          // P8: Yield after each provider completes - UI updates incrementally!
          yield List.from(results);
        } catch (e) {
          results.add(
            ProviderSearchResult(
              providerId: provider.id,
              providerName: provider.name,
              results: [],
              error: e.toString(),
            ),
          );
          yield List.from(results);
        }
      }
    });
