import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../../../../core/config/tmdb_config.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../details/presentation/tmdb_movie_details_screen.dart';
import '../../data/tmdb_provider.dart';

class DiscoverSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  DiscoverSearchDelegate(this.ref)
    : super(
        searchFieldLabel: 'Search movies, tv shows...',
        searchFieldStyle: const TextStyle(color: Colors.white70, fontSize: 18),
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        toolbarHeight: 70,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withOpacity(0.3),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      const SizedBox(width: 8),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.length < 2) return const SizedBox.shrink();

    return _SearchResultsGrid(query: query, ref: ref);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) return const SizedBox.shrink();

    return _SearchSuggestionsList(query: query, ref: ref);
  }
}

class _SearchSuggestionsList extends StatefulWidget {
  final String query;
  final WidgetRef ref;

  const _SearchSuggestionsList({required this.query, required this.ref});

  @override
  State<_SearchSuggestionsList> createState() => _SearchSuggestionsListState();
}

class _SearchSuggestionsListState extends State<_SearchSuggestionsList> {
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  @override
  void didUpdateWidget(covariant _SearchSuggestionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _fetchSuggestions();
    }
  }

  void _fetchSuggestions() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final tmdb = widget.ref.read(tmdbServiceProvider);
        final results = await tmdb.multiSearch(
          query: widget.query,
          language: 'en-US',
        );

        if (mounted) {
          setState(() {
            _suggestions = results.take(10).toList(); // Show top 10 suggestions
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final item = _suggestions[index];
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final year = (item['release_date'] ?? item['first_air_date'] ?? '')
            .split('-')
            .first;
        final posterPath = item['poster_path'];
        final mediaType = item['media_type'] ?? 'movie';

        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: posterPath != null
                ? CachedNetworkImage(
                    imageUrl: '${TmdbConfig.profileSizeUrl}$posterPath',
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ShimmerPlaceholder(),
                  )
                : Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, size: 20),
                  ),
          ),
          title: Text(
            title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          subtitle: Text(
            '$mediaType ${year.isNotEmpty ? '($year)' : ''}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TmdbMovieDetailsScreen(
                  movieId: item['id'],
                  mediaType: mediaType,
                  heroTag: 'search_${item['id']}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchResultsGrid extends ConsumerStatefulWidget {
  final String query;
  final WidgetRef ref;

  const _SearchResultsGrid({required this.query, required this.ref});

  @override
  ConsumerState<_SearchResultsGrid> createState() => _SearchResultsGridState();
}

class _SearchResultsGridState extends ConsumerState<_SearchResultsGrid> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchResults();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    try {
      final tmdb = ref.read(tmdbServiceProvider);
      final results = await tmdb.multiSearch(
        query: widget.query,
        language: 'en-US',
        page: 1,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _hasMore = results.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final tmdb = ref.read(tmdbServiceProvider);
      final nextPage = _page + 1;
      final results = await tmdb.multiSearch(
        query: widget.query,
        language: 'en-US',
        page: nextPage,
      );

      if (mounted) {
        setState(() {
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            _results.addAll(results);
            _page = nextPage;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _results.isEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isDesktop = screenWidth > 800;
      final maxExtent = isDesktop ? 240.0 : 150.0;
      final childAspectRatio = 0.55;

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 10,
        itemBuilder: (context, index) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ShimmerPlaceholder()),
              SizedBox(height: 8),
              ShimmerPlaceholder.rectangular(height: 14),
            ],
          );
        },
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "No results found for \"${widget.query}\"",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final maxExtent = isDesktop ? 240.0 : 150.0;
    final childAspectRatio = 0.55;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _results.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const ShimmerPlaceholder();
        }

        final item = _results[index];
        final posterPath = item['poster_path'];
        final imageUrl = posterPath != null
            ? '${TmdbConfig.posterSizeUrl}$posterPath'
            : 'https://via.placeholder.com/150x225';
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final id = item['id'];
        final mediaType = item['media_type'] ?? 'movie';
        final uniqueTag = 'search_result_${id}_$index';

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TmdbMovieDetailsScreen(
                  movieId: id,
                  mediaType: mediaType,
                  heroTag: uniqueTag,
                  placeholderPoster: imageUrl,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Hero(
                  tag: uniqueTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => const ShimmerPlaceholder(),
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
