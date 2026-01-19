import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/extensions/extension_manager.dart';

final homeDataProvider = FutureProvider<Map<String, List<MultimediaItem>>>((ref) async {
  // Force keepAlive to prevent disposed/rebuild loops on error
  ref.keepAlive();

  final activeProvider = ref.watch(activeProviderStateProvider);
  
  if (activeProvider == null) {
    return {
      'Error': [
        const MultimediaItem(
          title: 'No Provider Selected',
          url: '',
          posterUrl: '',
          description: 'Please select a provider in settings.',
        )
      ]
    };
  }

    // In a real implementation, providers return data structured by categories.
    // For now, since getHome() returns a flat list, we will manually categorize or just show one big list.
    // We'll treat the response as "Feature/Trending" content.
    try {
      final items = await activeProvider.getHome();
      if (items.isEmpty) {
        return {'No Data': []};
      }
      return items;
    } catch (e) {
      // Return a special 'Error' key to be handled by the UI
      return {
        'Error': [
          MultimediaItem(
            title: 'Error loading content',
            description: e.toString(),
            url: '',
            posterUrl: '',
          )
        ]
      };
    }
});
