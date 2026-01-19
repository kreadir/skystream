import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/shared/widgets/focusable_item.dart';
import 'package:skystream/shared/widgets/desktop_scroll_wrapper.dart';

class SearchResultSection extends ConsumerStatefulWidget {
  final String providerName;
  final String providerId;
  final List<MultimediaItem> results;

  const SearchResultSection({
    super.key,
    required this.providerName,
    required this.providerId,
    required this.results,
  });

  @override
  ConsumerState<SearchResultSection> createState() => _SearchResultSectionState();
}

class _SearchResultSectionState extends ConsumerState<SearchResultSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) return const SizedBox.shrink();

    final device = ref.watch(deviceProfileProvider).asData?.value;
    final isLarge = device?.isLargeScreen ?? false;

    final double width = isLarge ? 170 : 110;
    final double posterHeight = width * 1.5;
    final double totalHeight = posterHeight + 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.providerName,
                    style: isLarge
                        ? Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)
                        : Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  _buildDebugTag(context, ref),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: totalHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: widget.results.length,
              separatorBuilder: (context, index) =>
                  SizedBox(width: isLarge ? 24 : 12),
              itemBuilder: (context, rIndex) {
                final item = widget.results[rIndex];
                return FocusableItem(
                  onTap: () => context.push('/details', extra: item),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 2 / 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: item.posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                  color: Theme.of(context).dividerColor),
                              errorWidget: (context, url, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: isLarge ? 15 : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDebugTag(BuildContext context, WidgetRef ref) {
    bool isDebug = false;
    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final p = manager
          .getAllProviders()
          .firstWhere((p) => p.id == widget.providerId);
      if (p.isDebug) {
        isDebug = true;
      }
    } catch (_) {}

    if (!isDebug) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'DEBUG',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
