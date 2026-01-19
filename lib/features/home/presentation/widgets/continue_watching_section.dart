import 'package:flutter/material.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/features/home/presentation/widgets/continue_watching_card.dart';
import 'package:skystream/features/library/presentation/history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContinueWatchingSection extends ConsumerWidget {
  final String title;
  final List<HistoryItem> items;

  const ContinueWatchingSection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

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
          child: Text(
            title,
            style: isLarge
                ? Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: totalHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: isLarge ? 24 : 12),
            itemBuilder: (context, index) {
              return ContinueWatchingCard(
                historyItem: items[index],
                width: width,
                isLarge: isLarge,
              );
            },
          ),
        ),
      ],
    );
  }
}
