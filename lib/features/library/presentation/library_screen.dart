import 'package:skystream/shared/widgets/focusable_item.dart';
import 'package:skystream/shared/widgets/thumbnail_error_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../shared/widgets/multimedia_card.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryItems = ref.watch(libraryProvider);
    final isLarge = context.isTabletOrLarger;

    final double totalHeight = isLarge ? 180.0 : 150.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: libraryItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_outline_rounded,
                    size: 64,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your library is empty',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(LayoutConstants.spacingMd),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: totalHeight, // Responsive column sizing
                childAspectRatio: 2 / 3.4, // Matches poster aspect ratio
                crossAxisSpacing: LayoutConstants.spacingMd,
                mainAxisSpacing: LayoutConstants.spacingMd,
              ),
              itemCount: libraryItems.length,
              itemBuilder: (context, index) {
                final item = libraryItems[index];
                return MultimediaCard(
                  key: ValueKey(item.url),
                  imageUrl: AppImageFallbacks.poster(
                    item.posterUrl,
                    label: item.title,
                  ),
                  title: item.title,
                  heroTag: 'home_${item.url}_$index',
                  onTap: () => context.push(
                    '/details',
                    extra: DetailsRouteExtra(item: item),
                  ),
                );
              },
            ),
    );
  }
}
