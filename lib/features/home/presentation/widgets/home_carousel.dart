import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/shared/widgets/focusable_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';

class HomeCarousel extends ConsumerStatefulWidget {
  final List<MultimediaItem> items;

  const HomeCarousel({super.key, required this.items});

  @override
  ConsumerState<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends ConsumerState<HomeCarousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Default initialization, will be updated in build based on screen size if needed
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final device = ref.watch(deviceProfileProvider).asData?.value;
    final isLarge = device?.isLargeScreen ?? false;

    final double height = isLarge ? 550 : 240;
    final double viewportFraction = isLarge ? 0.6 : 0.9;
    final double radius = isLarge ? 24.0 : 16.0;

    // Re-create controller if viewport fraction changes (simplified approach)
    // Ideally we track this change, but for simplicity in build:
    if (_pageController.viewportFraction != viewportFraction) {
       _pageController.dispose();
       _pageController = PageController(viewportFraction: viewportFraction);
    }

    return SizedBox(
      height: height,
      child: DesktopScrollWrapper(
        controller: _pageController,
        scrollAmount: 400, // Fallback
        onScrollLeft: () async {
          await _pageController.previousPage(
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeInOut,
          );
        },
        onScrollRight: () async {
           await _pageController.nextPage(
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeInOut,
          );
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLarge ? 32 : 8,
                vertical: isLarge ? 24 : 0,
              ),
              child: FocusableItem(
                onTap: () => context.push('/details', extra: item),
                borderRadius: BorderRadius.circular(radius),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                       CachedNetworkImage(
                        imageUrl: item.bannerUrl ?? item.posterUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) => Container(color: Theme.of(context).dividerColor),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: isLarge ? 32 : 16,
                        left: isLarge ? 32 : 16,
                        right: isLarge ? 32 : 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: isLarge 
                                ? Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8),
                                    ]
                                  )
                                : Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.description != null) ...[
                              SizedBox(height: isLarge ? 12 : 4),
                              Text(
                                item.description!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                  fontSize: isLarge ? 16 : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
