import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/tmdb_config.dart';
import '../../details/presentation/tmdb_movie_details_screen.dart';
import '../../../../shared/widgets/tv_cards_wrapper.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../data/tmdb_provider.dart';

enum ViewAllCategory {
  popularMovies,
  popularTV,
  nowPlayingMovies,
  onTheAirTV,
  topRatedMovies,
  topRatedTV,
  airingTodayTV,
  trending,
}

class ViewAllScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Map<String, dynamic>> initialMediaList;
  final ViewAllCategory category;

  const ViewAllScreen({
    super.key,
    required this.title,
    required this.initialMediaList,
    required this.category,
  });

  @override
  ConsumerState<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends ConsumerState<ViewAllScreen> {
  late final ScrollController _scrollController;
  late List<Map<String, dynamic>> _mediaList;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _mediaList = List.from(widget.initialMediaList);
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialFill());
  }

  void _checkInitialFill() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent <= 0 &&
        _hasMore &&
        !_isLoading) {
      _fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final nextPage = _currentPage + 1;
      List<Map<String, dynamic>> newItems = [];

      switch (widget.category) {
        case ViewAllCategory.popularMovies:
          newItems = await tmdbService.getPopularMovies(page: nextPage);
          break;
        case ViewAllCategory.popularTV:
          newItems = await tmdbService.getPopularTV(page: nextPage);
          break;
        case ViewAllCategory.nowPlayingMovies:
          newItems = await tmdbService.getNowPlayingMovies(page: nextPage);
          break;
        case ViewAllCategory.onTheAirTV:
          newItems = await tmdbService.getOnTheAirTV(page: nextPage);
          break;
        case ViewAllCategory.topRatedMovies:
          newItems = await tmdbService.getTopRated(page: nextPage);
          break;
        case ViewAllCategory.topRatedTV:
          newItems = await tmdbService.getTopRatedTV(page: nextPage);
          break;
        case ViewAllCategory.airingTodayTV:
          newItems = await tmdbService.getAiringTodayTV(page: nextPage);
          break;
        case ViewAllCategory.trending:
          newItems = await tmdbService.getTrending(page: nextPage);
          break;
      }

      if (mounted) {
        setState(() {
          if (newItems.isEmpty) {
            _hasMore = false;
          } else {
            _mediaList.addAll(newItems);
            _currentPage = nextPage;
            // Recursively check if we need more to fill the screen
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _checkInitialFill(),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio for 2:3 posters
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final maxExtent = isDesktop ? 240.0 : 150.0;
    final crossAxisCount = (screenWidth / maxExtent).ceil();
    const childAspectRatio = 0.55;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black45,
            foregroundColor: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _mediaList.length + (_isLoading ? crossAxisCount : 0),
          itemBuilder: (context, index) {
            if (index >= _mediaList.length) {
              return const ShimmerPlaceholder();
            }

            final item = _mediaList[index];
            final posterPath = item['poster_path'];
            final imageUrl = posterPath != null
                ? '${TmdbConfig.posterSizeUrl}$posterPath'
                : 'https://via.placeholder.com/150x225';
            final itemTitle = item['title'] ?? item['name'] ?? 'Unknown';
            final uniqueTag =
                'view_all_${widget.category.name}_${item['id']}_$index';
            final mediaType =
                item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv');

            return TvCardsWrapper(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TmdbMovieDetailsScreen(
                      movieId: item['id'],
                      mediaType: mediaType,
                      heroTag: uniqueTag,
                      placeholderPoster: imageUrl,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
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
                          memCacheWidth: 350,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) =>
                              const ShimmerPlaceholder(),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.error_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
