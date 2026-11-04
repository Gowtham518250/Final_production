import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'device_capability_service.dart';

/// Runtime safeguards for entry-level Android devices.
///
/// Limits retained decoded images (which can be much larger in memory than
/// their compressed files) and releases unreferenced cached images when Android
/// reports memory pressure. This intentionally does not evict images currently
/// used by visible widgets.
class LowMemoryPerformance {
  LowMemoryPerformance._();

  static const int maximumCachedImages = 48;
  static const int maximumDecodedImageCacheBytes = 24 * 1024 * 1024;
  static const int lowMemoryMaximumCachedImages = 16;
  static const int lowMemoryMaximumDecodedImageCacheBytes = 8 * 1024 * 1024;

  /// Convert a widget's logical size to a bounded decode size in physical
  /// pixels. This avoids decoding multi-megapixel product photos for small
  /// catalog cards and cart thumbnails.
  static int decodeCacheDimension(
    double logicalPixels,
    double devicePixelRatio, {
    int minPixels = 64,
    int? maxPixels,
  }) {
    final effectiveMaxPixels = maxPixels ??
        (DeviceCapabilityService.instance.isLowEndDevice ? 768 : 960);
    if (!logicalPixels.isFinite ||
        !devicePixelRatio.isFinite ||
        logicalPixels <= 0 ||
        devicePixelRatio <= 0 ||
        minPixels <= 0 ||
        effectiveMaxPixels < minPixels) {
      throw ArgumentError('Invalid image decode dimensions or bounds.');
    }

    return (logicalPixels * devicePixelRatio)
        .round()
        .clamp(minPixels, effectiveMaxPixels)
        .toInt();
  }

  /// Use fewer continuous visual effects on entry-level devices.
  /// Device capability detection defaults to low-end until it completes, which
  /// keeps the first frame inexpensive on 2GB-class phones.
  static bool get useReducedMotion =>
      DeviceCapabilityService.instance.isLowEndDevice;

  static bool _configured = false;
  static final _memoryPressureObserver = _MemoryPressureObserver();

  /// Safe to call more than once; configured once before the first app frame.
  static void configure() {
    if (_configured) return;
    _configured = true;

    applyDeviceProfile();
    WidgetsBinding.instance.addObserver(_memoryPressureObserver);
  }

  /// Apply memory limits after device capability detection completes. Until
  /// then the app assumes a low-memory device so the first screen stays safe.
  static void applyDeviceProfile({bool? lowMemory}) {
    final useLowMemoryProfile =
        lowMemory ?? DeviceCapabilityService.instance.isLowEndDevice;
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = useLowMemoryProfile
        ? lowMemoryMaximumCachedImages
        : maximumCachedImages;
    cache.maximumSizeBytes = useLowMemoryProfile
        ? lowMemoryMaximumDecodedImageCacheBytes
        : maximumDecodedImageCacheBytes;
    if (kDebugMode) {
      debugPrint(
        '[LowMemoryPerformance] ${useLowMemoryProfile ? "low-memory" : "standard"} '
        'image cache: ${cache.maximumSize} entries / ${cache.maximumSizeBytes} bytes',
      );
    }
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
