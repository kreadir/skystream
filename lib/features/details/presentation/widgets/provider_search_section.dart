import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import '../details_screen.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../shared/widgets/tv_cards_wrapper.dart'; // Import TvCardsWrapper
import '../../../../shared/widgets/shimmer_placeholder.dart';

// Provider Result wrapper
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

// Localized Search Provider (Family to allow specific queries per instance if needed)
final providerSearchProvider = FutureProvider.family
    .autoDispose<List<ProviderSearchResult>, String>((ref, query) async {
      if (query.length < 2) return [];

      final manager = ref.read(extensionManagerProvider.notifier);
      final providers = manager.getAllProviders();

      // Parallel execution of all provider searches
      final futures = providers.map((provider) async {
        try {
          final rawResults = await provider.search(query);

          // Map to MultimediaItem & inject provider ID
          final results = rawResults.map((item) {
            return MultimediaItem(
              title: item.title,
              url: item.url,
              posterUrl: item.posterUrl,
              bannerUrl: item.bannerUrl,
              description: item.description,
              isFolder: item.isFolder,
              episodes: item.episodes,
              provider: provider.id,
            );
          }).toList();

          // Flexible filtering (Prefix match usually works best, but sometimes exact)
          final filtered = results.where((item) {
            final titleLower = item.title.toLowerCase();
            final queryLower = query.toLowerCase();
            // Allow partial matches
            return titleLower.contains(queryLower);
          }).toList();

          return ProviderSearchResult(
            providerId: provider.id,
            providerName: provider.name,
            results: filtered,
          );
        } catch (e) {
          return ProviderSearchResult(
            providerId: provider.id,
            providerName: provider.name,
            results: [],
            error: e.toString(),
          );
        }
      }).toList();

      return await Future.wait(futures);
    });

class ProviderSearchSection extends ConsumerStatefulWidget {
  final String query;
  final bool compact;

  const ProviderSearchSection({
    super.key,
    required this.query,
    this.compact = false,
  });

  @override
  ConsumerState<ProviderSearchSection> createState() =>
      _ProviderSearchSectionState();
}

class _ProviderSearchSectionState extends ConsumerState<ProviderSearchSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isEmpty) return const SizedBox.shrink();

    final plugins = ref.watch(extensionManagerProvider);
    final searchAsync = ref.watch(providerSearchProvider(widget.query));

    Widget content;
    if (plugins.isEmpty) {
      content = Container(
        height: 140,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "No plugins installed",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    } else {
      content = searchAsync.when(
        data: (results) {
          final allItems = <Map<String, dynamic>>[];
          for (var pResult in results) {
            for (var item in pResult.results) {
              allItems.add({
                'item': item,
                'providerName': pResult.providerName,
              });
            }
          }

          if (allItems.isEmpty) {
            return Container(
              height: 140,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "No streams found.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            );
          }

          return SizedBox(
            height: 140,
            child: DesktopScrollWrapper(
              controller: _scrollController,
              child: ListView.separated(
                controller: _scrollController,
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: widget.compact
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 16),
                itemCount: allItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final data = allItems[index];
                  final item = data['item'] as MultimediaItem;
                  final providerName = data['providerName'] as String;

                  return TvCardsWrapper(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(item: item),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 220,
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.surface,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              height: double.infinity,
                              child: item.posterUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.posterUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const ShimmerPlaceholder(),
                                    )
                                  : const ShimmerPlaceholder(),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        providerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const SizedBox(
          height: 140, // Fix 2: Force height for centering
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error: $err"),
        ),
      );
    }

    if (widget.compact) return content;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      clipBehavior: Clip.hardEdge, // Fix 1: Clip content to container borders
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  Icons.extension,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Available Sources",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                // Fix 3: Styled Beta Tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "BETA",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}
