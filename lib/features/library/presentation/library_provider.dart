import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/storage/storage_service.dart';

class LibraryNotifier extends Notifier<List<MultimediaItem>> {
  late StorageService _storage;

  @override
  List<MultimediaItem> build() {
    _storage = ref.watch(storageServiceProvider);
    return _storage.getLibraryItems();
  }

  Future<void> addItem(MultimediaItem item) async {
    await _storage.addToLibrary(item);
    state = _storage.getLibraryItems(); // Refresh state
  }

  Future<void> removeItem(String url) async {
    await _storage.removeFromLibrary(url);
    state = _storage.getLibraryItems(); // Refresh state
  }

  bool isBookmarked(String url) {
    return _storage.isInLibrary(url);
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, List<MultimediaItem>>(LibraryNotifier.new);
