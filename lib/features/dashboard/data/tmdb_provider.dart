import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tmdb_service.dart';
import 'language_provider.dart';
import 'filter_provider.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService();
});

final genresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  return service.getGenres(language: lang);
});

final trendingMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getTrending(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final popularMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getPopularMovies(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final nowPlayingMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getNowPlayingMovies(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final topRatedMoviesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getTopRated(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final popularTVProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getPopularTV(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final topRatedTVProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getTopRatedTV(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final onTheAirTVProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getOnTheAirTV(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final airingTodayTVProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  return service.getAiringTodayTV(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final dashboardHeroMovieProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(dashboardFilterProvider);
  final trending = await service.getTrendingAllDay(
    language: lang,
    genreId: filters.selectedGenre?['id'],
    year: filters.selectedYear,
    minRating: filters.minRating,
  );

  if (trending.isNotEmpty) {
    // Take top 5
    final topMovies = trending
        .take(5)
        .where((m) => m['media_type'] != 'person')
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final service = ref.read(tmdbServiceProvider);
    
    // Fetch genres to map IDs
    final allGenres = await ref.watch(genresProvider.future);
    final genreMap = {for (var g in allGenres) g['id']: g['name']};

    // Fetch logos and map genres for all 5 in parallel
    await Future.wait(
      topMovies.map((movie) async {
        final mediaType = movie['media_type'] ?? 'movie';
        
        // 1. Fetch Logo
        final logoUrl = await service.getBestLogo(
          movie['id'],
          language: lang,
          mediaType: mediaType,
        );
        if (logoUrl != null) {
          movie['logo_url'] = logoUrl;
        }

        // 2. Map Genres
        final genreIds = List<int>.from(movie['genre_ids'] ?? []);
        final genreNames = genreIds
            .map((id) => genreMap[id])
            .where((name) => name != null)
            .take(3)
            .join(' • ');
        
        movie['genres_str'] = genreNames;
      }),
    );

    return topMovies;
  }
  return [];
});
