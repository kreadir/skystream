import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/tmdb_config.dart';

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
    final heroHeight = size.height * 0.70;

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
                    color: Colors.white.withOpacity(
                      _currentIndex == entry.key ? 0.9 : 0.4,
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
    const genre = "Action"; // Placeholder

    final metadata = "$type • $genre${year.isNotEmpty ? ' • $year' : ''}";

    // Use a locally scoped AnimatedBuilder if controller exists
    if (widget.scrollController == null) {
      return _buildStaticItem(
        imageUrl,
        logoUrl,
        title,
        isMovie,
        metadata,
        height,
      );
    }

    return AnimatedBuilder(
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
        final opacity = (1.0 - (scrollOffset / (height * 0.5))).clamp(0.0, 1.0);

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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black12,
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87,
                        Colors.black,
                      ],
                      stops: [0.0, 0.4, 0.6, 0.85, 1.0],
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
                            child: Image.network(
                              logoUrl,
                              height: 140,
                              width: 300,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildTitleFallback(title),
                            ),
                          )
                        else
                          _buildTitleFallback(title),

                        // Metadata Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isMovie ? Icons.movie_outlined : Icons.tv,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              metadata,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        _buildButtons(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticItem(
    String imageUrl,
    String? logoUrl,
    String title,
    bool isMovie,
    String metadata,
    double height,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          height: height,
          width: double.infinity,
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black12,
                Colors.transparent,
                Colors.black87,
                Colors.black,
              ],
              stops: [0.0, 0.4, 0.85, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logoUrl != null)
                Image.network(
                  logoUrl,
                  height: 140,
                  width: 300,
                  fit: BoxFit.contain,
                )
              else
                _buildTitleFallback(title),
              Text(metadata, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 32),
              _buildButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.play_arrow, color: Colors.black, size: 28),
          label: const Text(
            "Play",
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            customBorder: const CircleBorder(),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white30, width: 1),
              ),
              child: const Icon(
                Icons.bookmark_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleFallback(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
        ),
      ),
    );
  }
}
