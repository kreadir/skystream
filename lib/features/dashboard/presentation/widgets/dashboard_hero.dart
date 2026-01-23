import 'package:flutter/material.dart';
import '../../../../core/config/tmdb_config.dart';

class DashboardHero extends StatelessWidget {
  final Map<String, dynamic> movie;

  const DashboardHero({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final posterPath = movie['poster_path'];
    final backdropPath = movie['backdrop_path'] ?? posterPath;
    final imageUrl = backdropPath != null
        ? '${TmdbConfig.imageBaseUrl}$backdropPath'
        : 'https://via.placeholder.com/500x750';

    final title = movie['title'] ?? movie['name'] ?? 'Unknown Title';
    final logoUrl = movie['logo_url']; // Provided by our updated provider
    final genres = "Action • Drama • Sci-Fi";

    final size = MediaQuery.of(context).size;

    // Nuvio-style: Tall immersive hero (85% of screen height)
    final heroHeight = size.height * 0.85;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image using Image.network directly for now
          // In a real app, use CachedNetworkImage
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey[900]),
          ),

          // 2. Gradient Overlay (Subtle top, Heavy bottom for text readability)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black26, // Minimal tint at top
                  Colors.transparent,
                  Colors.black54, // Start darkening
                  Colors.black, // Solid black at very bottom
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),

          // 3. Content (Logo/Title + Buttons)
          Positioned(
            left: 24,
            right: 24,
            bottom: 40, // Push content up from bottom edge
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo or Text Title
                if (logoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Image.network(
                      logoUrl,
                      height: 120, // Max height for logo
                      width: 280, // Restrict width
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                    ),
                  )
                else
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Roboto',
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),

                const SizedBox(height: 8),

                // Genres / Metadata
                Text(
                  genres,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),

                const SizedBox(height: 32),

                // Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconAction(Icons.add, "My List"),

                    // Play Button - Big and Visible
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 32,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),

                    _buildIconAction(Icons.info_outline, "Info"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
