import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final ShapeBorder shapeBorder;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.shapeBorder = const RoundedRectangleBorder(),
  });

  const ShimmerPlaceholder.rectangular({super.key, this.width, this.height})
    : shapeBorder = const RoundedRectangleBorder();

  const ShimmerPlaceholder.circular({
    super.key,
    this.width,
    this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(color: Colors.grey, shape: shapeBorder),
      ),
    );
  }
}
