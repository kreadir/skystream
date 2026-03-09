import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import '../data/tmdb_provider.dart';
import 'view_all_screen.dart';
import 'widgets/discover_carousel.dart';
import 'widgets/media_horizontal_list.dart';
import 'widgets/unified_filter_dialog.dart';
import '../data/filter_provider.dart';
import 'delegates/discover_search_delegate.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../core/models/tmdb_item.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final isScrolled =
        _scrollController.offset > 200; // Threshold for status bar switch
    if (isScrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = isScrolled;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final heroMovieAsync = ref.watch(discoverHeroMovieProvider); // Updated
    final popularMoviesAsync = ref.watch(popularMoviesProvider);
    final popularTVAsync = ref.watch(popularTVProvider);
    final nowPlayingAsync = ref.watch(nowPlayingMoviesProvider);
    final onTheAirTVAsync = ref.watch(onTheAirTVProvider);
    final topRatedMoviesAsync = ref.watch(topRatedMoviesProvider);
    final topRatedTVAsync = ref.watch(topRatedTVProvider);
    final airingTodayTVAsync = ref.watch(airingTodayTVProvider);

    return ValueListenableBuilder<bool>(
      valueListenable: _isScrolledNotifier,
      builder: (context, isScrolled, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

        return Scaffold(
          backgroundColor: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Base background
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            systemOverlayStyle: overlayStyle,
            forceMaterialTransparency: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                double offset = 0;
                if (_scrollController.hasClients) {
                  offset = _scrollController.offset * 0.8;
                }
                // Transition to black over 300 pixels
                final opacity = (offset / 300).clamp(0.0, 1.0);

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                );
              },
            ),
            title: Text(
              "Discover",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
              ),
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CardsWrapper(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const UnifiedFilterDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final filters = ref.watch(
                        discoverFilterProvider,
                      ); // Updated
                      // Language exclusion: Only highlight for content filters
                      final hasActiveFilter =
                          filters.selectedGenre != null ||
                          filters.selectedYear != null ||
                          filters.minRating != null;

                      return CircleAvatar(
                        backgroundColor: hasActiveFilter
                            ? Colors.blueAccent
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                        radius: 18,
                        child: Icon(
                          Icons.tune,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 18,
                        ),
                      );
                    },
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CardsWrapper(
                  onTap: () {
                    showSearch(
                      context: context,
                      delegate: DiscoverSearchDelegate(), // Updated
                    );
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.1),
                    radius: 18,
                    child: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: heroMovieAsync.when(
                  data: (movies) {
                    if (movies.isEmpty) return const SizedBox.shrink();
                    return DiscoverCarousel(
                      // Updated
                      movies: movies,
                      scrollController: _scrollController,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: 24.0),
                    child: SizedBox(
                      height: 500,
                      width: double.infinity,
                      child: ShimmerPlaceholder(),
                    ),
                  ),
                  error: (err, stack) => SizedBox(
                    height: 500,
                    child: Center(child: Text('Error: $err')),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  popularMoviesAsync,
                  "Popular Movies",
                  ViewAllCategory.popularMovies,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  popularTVAsync,
                  "Popular TV Shows",
                  ViewAllCategory.popularTV,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  nowPlayingAsync,
                  "New Movies",
                  ViewAllCategory.nowPlayingMovies,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  onTheAirTVAsync,
                  "New TV Shows",
                  ViewAllCategory.onTheAirTV,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  topRatedMoviesAsync,
                  "Featured Movies",
                  ViewAllCategory.topRatedMovies,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  topRatedTVAsync,
                  "Featured TV Shows",
                  ViewAllCategory.topRatedTV,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSection(
                  airingTodayTVAsync,
                  "Last videos TV Shows",
                  ViewAllCategory.airingTodayTV,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(
    AsyncValue<List<TmdbItem>> asyncValue,
    String title,
    ViewAllCategory category,
  ) {
    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return MediaHorizontalList(
          title: title,
          mediaList: items,
          category: category,
          heroTagPrefix: 'discover',
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Placeholder
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: ShimmerPlaceholder.rectangular(width: 150, height: 24),
            ),
            const SizedBox(height: 16),
            // List Placeholder
            SizedBox(
              height: 250,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const ShimmerPlaceholder.rectangular(
                        width: 130, // mobile width
                        height: 195,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const ShimmerPlaceholder.rectangular(
                      width: 100,
                      height: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
