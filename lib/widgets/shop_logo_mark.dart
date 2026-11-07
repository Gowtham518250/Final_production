import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../low_memory_performance.dart';

class ShopLogoMark extends StatelessWidget {
  const ShopLogoMark({
    super.key,
    required this.imageBytes,
    this.size = 48,
    this.fallbackColor = const Color(0xFF16A34A),
  });

  final Uint8List? imageBytes;
  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.28);
    final bytes = imageBytes;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.1),
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Icon(Icons.home_rounded, color: fallbackColor, size: size * 0.58)
          : LowMemoryPerformance.memoryImage(
              bytes,
              logicalSize: size,
              devicePixelRatio:
                  MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.home_rounded,
                color: fallbackColor,
                size: size * 0.58,
              ),
            ),
    );
  }
}
