import 'dart:io';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/services/download_service.dart';

/// Provider that tracks existing downloaded files on disk.
/// Maps URL strings to File objects if they exist.
final downloadedFilesProvider =
    NotifierProvider<DownloadedFilesNotifier, Map<String, File?>>(
      DownloadedFilesNotifier.new,
    );

class DownloadedFilesNotifier extends Notifier<Map<String, File?>> {
  @override
  Map<String, File?> build() {
    return const <String, File?>{};
  }

  Future<void> checkFile(MultimediaItem item, {Episode? episode}) async {
    final key = episode?.url ?? item.url;
    final downloadService = ref.read(downloadServiceProvider);
    final file = await downloadService.getDownloadedFile(
      item,
      episode: episode,
    );

    state = {...state, key: file};
  }

  void removeFile(String key) {
    state = {...state, key: null};
  }
}
