import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/extensions/base_provider.dart';

final homeDataProvider = FutureProvider<Map<String, List<MultimediaItem>>>((
  ref,
) async {
  final activeProvider = ref.watch(activeProviderStateProvider);

  if (activeProvider == null) {
    throw Exception(
      'No provider selected. Please select a provider in settings.',
    );
  }

  final items = await activeProvider.getHome();
  if (items.isEmpty) {
    throw Exception('No data returned from provider.');
  }

  // Only keep alive after successful load to allow retries on error
  ref.keepAlive();
  return items;
});

final homeFilterProvider = NotifierProvider<HomeFilterNotifier, ProviderType?>(() {
  return HomeFilterNotifier();
});

class HomeFilterNotifier extends Notifier<ProviderType?> {
  @override
  ProviderType? build() {
    final storage = ref.read(storageServiceProvider);
    final saved = storage.getHomeCategory();
    if (saved != null) {
      try {
        return ProviderType.values.firstWhere((e) => e.name == saved);
      } catch (_) {}
    }
    return null;
  }

  Future<void> setFilter(ProviderType? type) async {
    state = type;
    final storage = ref.read(storageServiceProvider);
    await storage.setHomeCategory(type?.name);
  }
}
