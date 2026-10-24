import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

/// Runtime safeguards for entry-level Android devices.
///
/// Limits retained decoded images (which can be much larger in memory than
/// their compressed files) and releases unreferenced cached images when Android
/// reports memory pressure. This intentionally does not evict images currently
/// used by visible widgets.
class LowMemoryPerformance {
  LowMemoryPerformance._();

  static const int maximumCachedImages = 80;
  static const int maximumDecodedImageCacheBytes = 40 * 1024 * 1024;

  /// Convert a widget's logical size to a bounded decode size in physical
  /// pixels. This avoids decoding multi-megapixel product photos for small
  /// catalog cards and cart thumbnails.
  static int decodeCacheDimension(
    double logicalPixels,
    double devicePixelRatio, {
    int minPixels = 64,
    int maxPixels = 1280,
  }) {
    if (!logicalPixels.isFinite ||
        !devicePixelRatio.isFinite ||
        logicalPixels <= 0 ||
        devicePixelRatio <= 0 ||
        minPixels <= 0 ||
        maxPixels < minPixels) {
      throw ArgumentError('Invalid image decode dimensions or bounds.');
    }

    return (logicalPixels * devicePixelRatio)
        .round()
        .clamp(minPixels, maxPixels)
        .toInt();
  }

  static bool _configured = false;
  static final _memoryPressureObserver = _MemoryPressureObserver();

  /// Safe to call more than once; configured once before the first app frame.
  static void configure() {
    if (_configured) return;
    _configured = true;

    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = maximumCachedImages;
    cache.maximumSizeBytes = maximumDecodedImageCacheBytes;
    WidgetsBinding.instance.addObserver(_memoryPressureObserver);
  }
}

class _MemoryPressureObserver extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    // clear() keeps currently-live images intact while discarding cache entries
    // that are no longer referenced by visible widgets.
    PaintingBinding.instance.imageCache.clear();
    if (kDebugMode) {
      debugPrint('[LowMemoryPerformance] Released cached image memory.');
    }
  }
}
