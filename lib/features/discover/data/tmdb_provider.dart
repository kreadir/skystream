import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tmdb_service.dart';
import 'language_provider.dart';
import 'filter_provider.dart';

import '../../../core/network/dio_client_provider.dart';
import '../../../core/models/tmdb_item.dart';
import '../../../core/models/tmdb_genre.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService(ref.watch(dioClientProvider));
});

final genresProvider = FutureProvider<List<TmdbGenre>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  return service.getGenres(language: lang);
});

final trendingMoviesProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getTrending(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final popularMoviesProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getPopularMovies(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final nowPlayingMoviesProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getNowPlayingMovies(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final topRatedMoviesProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getTopRated(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final popularTVProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getPopularTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final topRatedTVProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getTopRatedTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final onTheAirTVProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getOnTheAirTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final airingTodayTVProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  return service.getAiringTodayTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final discoverHeroMovieProvider = FutureProvider<List<TmdbItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = await ref.watch(languageProvider.future);
  final filters = ref.watch(discoverFilterProvider);
  final trending = await service.getTrendingAllDay(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );

  if (trending.isNotEmpty) {
    // Take top 5
    final topMovies = trending
        .where((m) => m.mediaType != 'person')
        .take(5)
        .toList();
    final service = ref.read(tmdbServiceProvider);

    // Fetch metadata + logos for top 5 (Consistent with Details Screen)
    await Future.wait(
      topMovies.map((movie) async {
        final id = movie.id;
        final mediaType = movie.mediaType;

        // Fetch full details
        final details = mediaType == 'tv'
            ? await service.getTvDetails(id, language: lang)
            : await service.getMovieDetails(id, language: lang);

        if (details != null) {
          // 1. Extract Logo from 'images' (via append_to_response)
          if (details['images'] != null) {
            final logos = List<Map<String, dynamic>>.from(
              details['images']['logos'] ?? [],
            );
            final logoUrl = TmdbService.pickBestLogo(logos, lang);
            if (logoUrl != null) {
              movie.logoUrl = logoUrl;
            }
          }

          // 2. Map Genres from details directly
          if (details['genres'] != null) {
            final genres = List<Map<String, dynamic>>.from(
              details['genres'],
            ).take(3).map((g) => g['name']).join(' • ');
            movie.genresStr = genres;
          }
        }
      }),
    );

    return topMovies;
  }
  return [];
});
