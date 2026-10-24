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
