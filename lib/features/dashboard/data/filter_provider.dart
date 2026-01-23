import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilterState {
  final Map<String, dynamic>? selectedGenre; // {id: 123, name: 'Action'}
  final int? selectedYear;
  final double? minRating;

  const FilterState({this.selectedGenre, this.selectedYear, this.minRating});

  FilterState copyWith({
    Map<String, dynamic>? selectedGenre,
    int? selectedYear,
    double? minRating,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearRating = false,
  }) {
    return FilterState(
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      selectedYear: clearYear ? null : (selectedYear ?? this.selectedYear),
      minRating: clearRating ? null : (minRating ?? this.minRating),
    );
  }
}

class FilterNotifier extends Notifier<FilterState> {
  @override
  FilterState build() => const FilterState();

  void setGenre(Map<String, dynamic>? genre) {
    state = state.copyWith(selectedGenre: genre, clearGenre: genre == null);
  }

  void setYear(int? year) {
    state = state.copyWith(selectedYear: year, clearYear: year == null);
  }

  void setRating(double? rating) {
    state = state.copyWith(minRating: rating, clearRating: rating == null);
  }
  
  void clearAll() {
    state = const FilterState();
  }
}

final dashboardFilterProvider = NotifierProvider<FilterNotifier, FilterState>(() => FilterNotifier());
