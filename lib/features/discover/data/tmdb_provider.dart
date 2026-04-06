import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tmdb_service.dart';
import 'language_provider.dart';
import 'filter_provider.dart';

import '../../../core/network/dio_client_provider.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/models/tmdb_genre.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService(ref.watch(dioClientProvider));
});

final genresProvider = FutureProvider<List<TmdbGenre>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final isEnglish = lang == 'en-US';

  // Always fetch movie + TV genres. For non-English languages also fetch
  // English so we can substitute empty names (TMDB returns "" for genres it
  // hasn't translated instead of falling back to English).
  final futures = [
    service.getGenres(language: lang),
    service.getTvGenres(language: lang),
    if (!isEnglish) service.getGenres(language: 'en-US'),
    if (!isEnglish) service.getTvGenres(language: 'en-US'),
  ];
  final results = await Future.wait(futures);

  // Build English fallback map (id → English name).
  final enFallback = <int, String>{};
  if (!isEnglish) {
    for (final g in [...results[2], ...results[3]]) {
      enFallback[g.id] = g.name;
    }
  }

  final seen = <int>{};
  final merged = <TmdbGenre>[];
  for (final g in [...results[0], ...results[1]]) {
    if (seen.add(g.id)) {
      final fallback = enFallback[g.id] ?? '';
      merged.add(g.name.isNotEmpty ? g : g.withName(fallback));
    }
  }
  // Remove any genres that ended up with no name at all.
  merged.removeWhere((g) => g.name.isEmpty);
  merged.sort((a, b) => a.name.compareTo(b.name));
  return merged;
});

final trendingMoviesProvider = FutureProvider<List<MultimediaItem>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getTrending(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final popularMoviesProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getPopularMovies(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final nowPlayingMoviesProvider = FutureProvider<List<MultimediaItem>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getNowPlayingMovies(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final topRatedMoviesProvider = FutureProvider<List<MultimediaItem>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getTopRated(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final popularTVProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getPopularTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final topRatedTVProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getTopRatedTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final onTheAirTVProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getOnTheAirTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final airingTodayTVProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);
  return service.getAiringTodayTV(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );
});

final discoverHeroMovieProvider = FutureProvider<List<MultimediaItem>>((
  ref,
) async {
  final service = ref.watch(tmdbServiceProvider);
  final lang = ref.watch(languageProvider);
  final filters = ref.watch(discoverFilterProvider);

  var trending = await service.getTrendingAllDay(
    language: lang,
    genreId: filters.selectedGenre?.id,
    year: filters.selectedYear,
    minRating: filters.minRating,
  );

  // For regional languages the filtered discover call may return very few
  // items. Fall back to global trending so the carousel always has content.
  final mediaItems = trending
      .where(
        (m) =>
            m.contentType == MultimediaContentType.movie ||
            m.contentType == MultimediaContentType.series,
      )
      .toList();

  if (mediaItems.length < 3 && lang != 'en-US') {
    trending = await service.getTrendingAllDay(language: 'en-US');
  }

  final topMovies = trending
      .where(
        (m) =>
            m.contentType == MultimediaContentType.movie ||
            m.contentType == MultimediaContentType.series,
      )
      .take(5)
      .toList();

  if (topMovies.isEmpty) return [];

  final svc = ref.read(tmdbServiceProvider);

  final enriched = await Future.wait(
    topMovies.map((movie) async {
      try {
        // Use content-type (not the broken mediaType string getter) to pick
        // the correct TMDB endpoint. Lightweight call: images only — no
        // credits, videos, or translations.
        final tmdbType = movie.contentType == MultimediaContentType.series
            ? 'tv'
            : 'movie';
        final details = await svc.getDetailsForCarousel(
          movie.id,
          tmdbType,
          language: lang,
        );

        if (details == null) return movie;

        String? logoUrl;
        if (details['images'] != null) {
          final logos = List<Map<String, dynamic>>.from(
            details['images']['logos'] ?? [],
          );
          logoUrl = TmdbService.pickBestLogo(logos, lang);
        }

        String? genresStr;
        if (details['genres'] != null) {
          genresStr = List<Map<String, dynamic>>.from(details['genres'])
              .take(3)
              .map((g) => g['name'])
              .join(' • ');
        }

        return movie.copyWith(
          logoUrl: logoUrl,
          tags: genresStr != null ? [genresStr] : null,
        );
      } catch (_) {
        // Don't let one failed enrichment break the whole carousel.
        return movie;
      }
    }),
  );

  return enriched;
});
