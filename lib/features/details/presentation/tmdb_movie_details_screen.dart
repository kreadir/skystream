import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tmdb_details.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/tmdb_config.dart';

import 'widgets/provider_search_section.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../data/tmdb_details_provider.dart';
import 'tmdb_details_controller.dart';
import 'widgets/movie_cast_list.dart';
import 'widgets/movie_trailers_carousel.dart';
import 'widgets/movie_production_companies.dart';
import 'widgets/movie_seasons_list.dart';

class TmdbMovieDetailsScreen extends ConsumerStatefulWidget {
  final int movieId;
  final String mediaType; // 'movie' or 'tv'
  final String? heroTag;
  final String? placeholderPoster;

  const TmdbMovieDetailsScreen({
    super.key,
    required this.movieId,
    this.mediaType = 'movie',
    this.heroTag,
    this.placeholderPoster,
  });

  @override
  ConsumerState<TmdbMovieDetailsScreen> createState() =>
      _TmdbMovieDetailsScreenState();
}

class _TmdbMovieDetailsScreenState
    extends ConsumerState<TmdbMovieDetailsScreen> {
  bool _isDescriptionExpanded = false;
  late ScrollController _scrollController;
  final ValueNotifier<bool> _showAppBarTitle = ValueNotifier<bool>(false);

  late final ScrollController _castScrollController;
  late final ScrollController _trailerScrollController;

  late final ScrollController _episodeScrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _castScrollController = ScrollController();
    _trailerScrollController = ScrollController();

    _episodeScrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    if (widget.mediaType == 'tv') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(tmdbDetailsControllerProvider(widget.movieId).notifier)
            .fetchEpisodes(1);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _castScrollController.dispose();
    _trailerScrollController.dispose();

    _episodeScrollController.dispose();
    _showAppBarTitle.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 450;
    if (show != _showAppBarTitle.value) {
      _showAppBarTitle.value = show;
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = MovieDetailsParams(widget.movieId, widget.mediaType);
    final detailsAsync = ref.watch(movieDetailsProvider(params));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: detailsAsync.when(
        data: (data) {
          if (data == null) {
            return Center(
              child: Text(
                "Content not found",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          }
          if (context.isDesktop) {
            return _buildDesktopLayout(data);
          }
          return _buildMobileLayout(data);
        },
        loading: () => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Failed to load content",
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(movieDetailsProvider(params)),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(TmdbDetails data) {
    final isMovie = widget.mediaType == 'movie';
    final backdropPath = data.backdropPath;
    final title = data.title;
    final overview = data.overview;

    final runtime = data.runtime;
    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    final durationText = hours > 0 ? '${hours}H ${minutes}M' : '${minutes}M';

    final releaseDate = data.releaseDateFull;
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final rating = data.voteAverage.toStringAsFixed(1);
    final genreText = data.genresStr ?? '';

    final certification = data.certification;
    final seasons = data.seasons;
    final cast = data.cast;
    final director = data.director;
    final logoUrl = data.logoUrl;
    final trailers = data.trailers;
    final productionCompanies = data.productionCompanies;
    final status = data.status;
    final budget = data.budget;
    final revenue = data.revenue;
    final tagline = data.tagline;
    final originCountry = data.originCountry;
    final originalLanguage = data.originalLanguage;
    final releaseDateFull = data.releaseDateFull;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.black45 : Colors.white54,
            foregroundColor: textColor,
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backdropPath != null)
            Positioned.fill(
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [scaffoldColor, Colors.transparent],
                    stops: const [0.2, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstOut,
                child: CachedNetworkImage(
                  imageUrl: '${TmdbConfig.imageBaseUrl}$backdropPath',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    scaffoldColor.withValues(alpha: 0.8),
                    scaffoldColor.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [scaffoldColor, Colors.transparent],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6, // 60% Width
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (logoUrl != null)
                          CachedNetworkImage(
                            imageUrl: logoUrl,
                            height: 200,
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.contain,
                            // In Light mode, white logos might be invisible.
                            //Ideally we need dark logos for light mode but TMDB API is tricky.
                            // For now, we rely on the fact most logos are colored or white.
                            // If white on white, it fails.
                            // Adding a shadow could help, but let's stick to standard logic first.
                            placeholder: (_, _) => Text(
                              title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                          )
                        else
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              year.isNotEmpty ? "$year  •  " : "",
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              durationText,
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: textSecondary),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                certification,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF01B4E4), // TMDB Blue
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "TMDB",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Color(0xFF01B4E4),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (director != "Unknown") ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Director: $director",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          overview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          genreText,
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Icon(
                              Icons.extension,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Available Sources",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
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
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(
                            maxWidth: 600,
                            maxHeight: 220,
                          ),
                          child: ProviderSearchSection(
                            query: title,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  if (!isMovie) ...[
                    MovieSeasonsList(
                      movieId: widget.movieId,
                      seasons: seasons,
                      textColor: textColor,
                    ),
                  ],

                  if (cast.isNotEmpty) ...[
                    MovieCastList(
                      cast: cast,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ],

                  if (trailers.isNotEmpty) ...[
                    MovieTrailersCarousel(
                      trailers: trailers,
                      textColor: textColor,
                    ),
                  ],
                  if (productionCompanies.isNotEmpty) ...[
                    MovieProductionCompanies(
                      productionCompanies: productionCompanies,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ],

                  // 5. Details (Rich Stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMovie ? "Movie Details" : "Show Details",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (tagline.isNotEmpty) ...[
                        _buildDetailItem(
                          "Tagline",
                          "\"$tagline\"",
                          italic: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 40,
                        runSpacing: 24,
                        children: [
                          _buildDetailItem("Status", status),
                          _buildDetailItem(
                            isMovie ? "Release Date" : "First Air Date",
                            releaseDateFull.isNotEmpty
                                ? DateFormat(
                                    'MMMM d, yyyy',
                                  ).format(DateTime.parse(releaseDateFull))
                                : 'Unknown',
                          ),
                          _buildDetailItem(
                            "Original Language",
                            originalLanguage,
                          ),
                          _buildDetailItem("Origin Country", originCountry),
                          if (budget > 0)
                            _buildDetailItem(
                              "Budget",
                              NumberFormat.currency(
                                symbol: '\$',
                                decimalDigits: 0,
                              ).format(budget),
                            ),
                          if (revenue > 0)
                            _buildDetailItem(
                              "Revenue",
                              NumberFormat.currency(
                                symbol: '\$',
                                decimalDigits: 0,
                              ).format(revenue),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool italic = false}) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(TmdbDetails data) {
    final isMovie = widget.mediaType == 'movie';

    final backdropPath = data.backdropPath;
    final title = data.title;
    final overview = data.overview;

    final tagline = data.tagline;
    final runtime = data.runtime;
    final releaseDate = data.releaseDateFull;
    final status = data.status;
    final budget = data.budget;
    final genres = data.genres;
    final cast = data.cast;
    final productionCompanies = data.productionCompanies;
    final trailers = data.trailers;

    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    final durationText = hours > 0 ? '${hours}H ${minutes}M' : '${minutes}M';
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final rating = data.voteAverage.toStringAsFixed(1);

    final certification = data.certification;
    final director = data.director;
    final logoUrl = data.logoUrl;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 550,
          pinned: true,
          backgroundColor: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Theme aware
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
              radius: 18,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          title: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              double offset = 0;
              if (_scrollController.hasClients) {
                offset = _scrollController.offset;
              }
              // Fade in as the main logo fades out (Main logo fully hidden at 300)
              final double opacity = ((offset - 300) / 100).clamp(0.0, 1.0);

              if (opacity <= 0) return const SizedBox.shrink();

              return Opacity(
                opacity: opacity,
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.0,
                  ),
                ),
              );
            },
          ),
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            background: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                double offset = 0.0;
                if (_scrollController.hasClients) {
                  offset = _scrollController.offset;
                }
                final opacity = (1.0 - (offset / 300)).clamp(0.0, 1.0);
                final contentOffset = -offset * 0.4;
                final parallaxOffset = -offset * 0.1;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Backdrop Image
                    if (backdropPath != null)
                      Transform.translate(
                        offset: Offset(0, parallaxOffset),
                        child: CachedNetworkImage(
                          imageUrl: '${TmdbConfig.imageBaseUrl}$backdropPath',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),

                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).scaffoldBackgroundColor
                                .withValues(alpha: 0.0), // Top transparent
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.0),
                            Theme.of(context).scaffoldBackgroundColor
                                .withValues(alpha: 0.8), // Fog
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor, // Bottom solid
                          ],
                          stops: const [0.0, 0.4, 0.8, 1.0],
                        ),
                      ),
                    ),

                    // Content Overlay (Title, Genre, Buttons) -> CENTERED
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Transform.translate(
                        offset: Offset(0, contentOffset),
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.center, // Centered
                            children: [
                              // Movie Logo or Text Title
                              if (logoUrl != null) ...[
                                if (logoUrl.toLowerCase().endsWith('.svg'))
                                  SvgPicture.network(
                                    logoUrl,
                                    width: 280,
                                    height: 120,
                                    fit: BoxFit.contain,
                                    // If logo is black in light mode, it works. If white, it disappears on white bg.
                                    // However, we fixed logo priority to be Color/PNG.
                                    // If we have a White text logo on White background -> Invisible.
                                    // We might need a shadow or auto-color?
                                    // But usually logos are color.
                                  )
                                else
                                  CachedNetworkImage(
                                    imageUrl: logoUrl,
                                    width: 280,
                                    height: 120,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center, // Centered
                                  ),
                              ] else
                                Text(
                                  title.toUpperCase(),
                                  textAlign: TextAlign.center, // Centered
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 40,
                                    fontFamily: 'RobotoCondensed',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),

                              const SizedBox(height: 8),
                              // Genre
                              Text(
                                genres.isNotEmpty
                                    ? genres.take(3).join(' • ')
                                    : (isMovie ? 'Movie' : 'TV Show'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 2. Metadata, Synopsis, Cast, Production, Trailers, Details
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source Search (Provider Integration)
                ProviderSearchSection(query: title),
                const SizedBox(height: 24),

                // Metadata Row: 2026  1H 56M  [PG-13]
                Row(
                  children: [
                    Text(
                      year,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildTmdbLogo(),
                    const SizedBox(width: 8),
                    Text(
                      rating,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 20),
                    if (runtime > 0) ...[
                      Text(
                        durationText,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        certification,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isMovie && data.seasons.isNotEmpty) ...[
                      const SizedBox(width: 20),
                      Text(
                        "${data.seasons.length} Seasons",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Director / Creator
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: isMovie ? "Director: " : "Creator: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      TextSpan(text: director),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Synopsis with Expansion
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overview,
                        maxLines: _isDescriptionExpanded ? null : 3,
                        overflow: _isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (overview.length > 150)
                        GestureDetector(
                          onTap: () => setState(
                            () => _isDescriptionExpanded =
                                !_isDescriptionExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  _isDescriptionExpanded
                                      ? "Show Less"
                                      : "Show More",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  _isDescriptionExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Cast Section
                if (cast.isNotEmpty) ...[MovieCastList(cast: cast)],

                // Production Section
                if (productionCompanies.isNotEmpty) ...[
                  MovieProductionCompanies(
                    productionCompanies: productionCompanies,
                  ),
                ],

                // Trailers Section
                if (trailers.isNotEmpty) ...[
                  MovieTrailersCarousel(trailers: trailers),
                ],

                if (!isMovie && data.seasons.isNotEmpty) ...[
                  MovieSeasonsList(
                    movieId: widget.movieId,
                    seasons: data.seasons,
                  ),
                ],

                // Movie Details Table
                Text(
                  isMovie ? "MOVIE DETAILS" : "SHOW DETAILS",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                if (tagline.isNotEmpty)
                  _buildDetailRow("Tagline", "\"$tagline\""),
                _buildDetailRow("Status", status),
                _buildDetailRow(
                  isMovie ? "Release Date" : "First Air Date",
                  DateFormat(
                    'MMMM d, yyyy',
                  ).format(DateTime.parse(releaseDate)),
                ),
                if (budget > 0)
                  _buildDetailRow(
                    "Budget",
                    NumberFormat.currency(
                      symbol: '\$',
                      decimalDigits: 0,
                    ).format(budget),
                  ),
                _buildDetailRow("Origin Country", data.originCountry),
                _buildDetailRow("Original Language", data.originalLanguage),

                const SizedBox(height: 32),

                // Safe Area padding

                // Safe Area padding
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTmdbLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF01B4E4), // TMDB Blue
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        "TMDB",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
