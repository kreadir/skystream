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
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final service = ref.read(
      tmdbServiceProvider,
    ); // Keep read here for internal calls

    // Fetch logos for all 5 in parallel
    await Future.wait(
      topMovies.map((movie) async {
        // getBestLogo now handles international/textless priority internally
        final logoUrl = await service.getBestLogo(
          movie['id'],
          language: lang,
        ); // Pass lang here too
        if (logoUrl != null) {
          movie['logo_url'] = logoUrl;
        }
      }),
    );

    return topMovies;
  }
  return [];
});
