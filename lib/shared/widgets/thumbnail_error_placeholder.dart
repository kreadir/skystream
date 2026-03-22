import 'package:flutter/material.dart';

/// Consistent error/missing-image placeholder for thumbnails and posters.
///
/// Renders entirely on-device — zero network calls.
/// When a [label] is provided, it shows the title text inside the placeholder
/// box so the user knows what content is missing.
class ThumbnailErrorPlaceholder extends StatelessWidget {
  final double? iconSize;
  final String? label;
  final bool isBackdrop;

  const ThumbnailErrorPlaceholder({
    super.key,
    this.iconSize,
    this.label,
    this.isBackdrop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.onPrimaryFixed;
    final fg = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    final size = iconSize ?? 32.0;

    // When we have a label, show the title text — same visual as placehold.co
    // but rendered locally with zero network overhead.
    if (label != null && label!.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: bg,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBackdrop
                  ? Icons.movie_outlined
                  : Icons.image_not_supported_outlined,
              size: size,
              color: fg,
            ),
            const SizedBox(height: 6),
            Text(
              label!,
              maxLines: isBackdrop ? 2 : 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: isBackdrop ? 12 : 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // No label — just an icon in a coloured box.
    return Container(
      color: bg,
      child: Center(
        child: Icon(Icons.broken_image, size: size, color: fg),
      ),
    );
  }
}
