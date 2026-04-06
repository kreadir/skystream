import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/extensions/base_provider.dart';

final homeDataProvider =
    AsyncNotifierProvider<HomeDataNotifier, Map<String, List<MultimediaItem>>>(
      HomeDataNotifier.new,
      // Disable Riverpod 3's built-in exponential-backoff retry.
      // Home data errors should be surfaced immediately; the user retries manually.
      retry: (_, _) => null,
    );

/// Uses AsyncNotifierProvider so [_keepAliveLink] is stored as an instance
/// variable. A local variable in a FutureProvider body becomes GC-eligible
/// after the body throws, which closes the KeepAliveLink and triggers
/// auto-dispose — causing an infinite retry loop in Riverpod 3.
class HomeDataNotifier
    extends AsyncNotifier<Map<String, List<MultimediaItem>>> {
  // ignore: unused_field — held to prevent GC from releasing the KeepAliveLink
  Object? _keepAliveLink;

  @override
  Future<Map<String, List<MultimediaItem>>> build() async {
    // Store on the instance so it survives even when build() throws.
    // A local variable in a FutureProvider body becomes GC-eligible after
    // the body throws, which closes the link and triggers auto-dispose.
    _keepAliveLink = ref.keepAlive();

    final activeProvider = ref.watch(activeProviderStateProvider);

    if (activeProvider == null) {
      throw Exception(
        'No provider selected. Please select a provider in settings.',
      );
    }

    // Fast connectivity check
    try {
      final result = await InternetAddress.lookup(
        'dns.google',
      ).timeout(const Duration(seconds: 2));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection');
      }
    } catch (_) {
      throw Exception('No internet connection');
    }

    final items = await activeProvider.getHome();
    if (items.isEmpty) {
      throw Exception('No data returned from provider.');
    }

    return items;
  }
}

final homeFilterProvider = NotifierProvider<HomeFilterNotifier, ProviderType?>(
  () {
    return HomeFilterNotifier();
  },
);

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
