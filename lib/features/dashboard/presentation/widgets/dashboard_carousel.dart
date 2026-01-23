import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/config/tmdb_config.dart';
import '../../../details/presentation/tmdb_movie_details_screen.dart';

class DashboardCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> movies;
  final ScrollController? scrollController;

  const DashboardCarousel({
    super.key,
    required this.movies,
    this.scrollController,
  });

  @override
  State<DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends State<DashboardCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final heroHeight = size.height * 0.60;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        children: [
          CarouselSlider.builder(
            itemCount: widget.movies.length,
            options: CarouselOptions(
              height: heroHeight,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 15),
              autoPlayAnimationDuration: const Duration(milliseconds: 1000),
              autoPlayCurve: Curves.fastOutSlowIn,
              scrollPhysics: const BouncingScrollPhysics(),
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            itemBuilder: (context, index, realIndex) {
              final movie = widget.movies[index];
              return _buildCarouselItem(context, movie, heroHeight);
            },
          ),

          // Animated Pagination Dots
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.movies.asMap().entries.map((entry) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentIndex == entry.key ? 24.0 : 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(
                      _currentIndex == entry.key ? 0.9 : 0.3, // Slightly lower opacity for inactive
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetails(BuildContext context, Map<String, dynamic> movie) {
    // Determine type: 'title' usually implies movie, 'name' implies TV
    // But better to check 'media_type' if available (trending/search provides it), 
    // fallback to title check.
    String mediaType = movie['media_type'] ?? (movie['title'] != null ? 'movie' : 'tv');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TmdbMovieDetailsScreen(
          movieId: movie['id'],
          mediaType: mediaType,
          heroTag: 'hero_${movie['id']}',
        ),
      ),
    );
  }

  Widget _buildCarouselItem(
    BuildContext context,
    Map<String, dynamic> movie,
    double height,
  ) {
    final posterPath = movie['poster_path'];
    final backdropPath = movie['backdrop_path'] ?? posterPath;
    final imageUrl = backdropPath != null
        ? '${TmdbConfig.imageBaseUrl}$backdropPath'
        : 'https://via.placeholder.com/500x750';

    final title = movie['title'] ?? movie['name'] ?? 'Unknown';
    final logoUrl = movie['logo_url'];

    // Metadata parsing
    final releaseDate = movie['release_date'] ?? movie['first_air_date'] ?? '';
    final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';
    final isMovie = movie['title'] != null;
    final type = isMovie ? "Movie" : "TV Show";
    final genres = movie['genres_str'] as String? ?? '';
    
    final metadata = [
      type,
      if (genres.isNotEmpty) genres,
      if (year.isNotEmpty) year,
    ].join(' • ');

    // Use a locally scoped AnimatedBuilder if controller exists
    if (widget.scrollController == null) {
      return _buildStaticItem(
        context,
        imageUrl,
        logoUrl,
        title,
        isMovie,
        metadata,
        height,
        movie,
      );
    }

    return GestureDetector(
      onTap: () => _navigateToDetails(context, movie),
      child: AnimatedBuilder(
        animation: widget.scrollController!,
        builder: (context, child) {
          double scrollOffset = 0.0;
          if (widget.scrollController!.hasClients) {
            scrollOffset = widget.scrollController!.offset;
          }

          // Parallax effect: Background moves slower than foreground
          final parallaxOffset = scrollOffset * 0.1;

          // Content effect: Slide up faster and fade out
          final contentOffset = -scrollOffset * 0.2;
          final opacity = (1.0 - (scrollOffset / (height * 0.5))).clamp(
            0.0,
            1.0,
          );

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Parallax Background
                Transform.translate(
                  offset: Offset(0, parallaxOffset),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    height: height,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        Container(color: Colors.black12),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.black),
                  ),
                ),

                // 2. Static Gradient
                Transform.translate(
                  offset: Offset(0, parallaxOffset),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.6),
                          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.4, 0.6, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Animated Content
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 50,
                  child: Transform.translate(
                    offset: Offset(0, contentOffset),
                    child: Opacity(
                      opacity: opacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo or Title Fallback
                          if (logoUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: _buildLogo(logoUrl, title),
                            )
                          else
                            _buildTitleFallback(title),

                          // Metadata Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isMovie ? Icons.movie_outlined : Icons.tv,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                metadata,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    if (Theme.of(context).brightness == Brightness.dark)
                                      const Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticItem(
    BuildContext context,
    String imageUrl,
    String? logoUrl,
    String title,
    bool isMovie,
    String metadata,
    double height,
    Map<String, dynamic> movie,
  ) {
    return GestureDetector(
      onTap: () => _navigateToDetails(context, movie),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            height: height,
            width: double.infinity,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.4, 0.85, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 30, // Adjusted from 50
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (logoUrl != null)
                  _buildLogo(logoUrl, title)
                else
                  _buildTitleFallback(title),
                Text(metadata, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(String logoUrl, String title) {
    if (logoUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        logoUrl,
        height: 140,
        width: 300,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => const SizedBox(
          height: 140,
          width: 300,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: logoUrl,
      height: 140,
      width: 300,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      placeholder: (context, url) => const SizedBox(
        height: 140,
        width: 300,
      ),
      errorWidget: (context, url, error) => _buildTitleFallback(title),
    );
  }

  Widget _buildTitleFallback(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 40,
          fontFamily: 'RobotoCondensed',
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          shadows: [
             if (Theme.of(context).brightness == Brightness.dark)
               const Shadow(color: Colors.black, blurRadius: 10)
          ],
        ),
      ),
    );
  }
}
