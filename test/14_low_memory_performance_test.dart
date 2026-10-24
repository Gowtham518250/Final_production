import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/low_memory_performance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decoded image cache is bounded for low-memory devices', () {
    LowMemoryPerformance.configure();

    final cache = PaintingBinding.instance.imageCache;
    expect(cache.maximumSize, LowMemoryPerformance.maximumCachedImages);
    expect(
      cache.maximumSizeBytes,
      LowMemoryPerformance.maximumDecodedImageCacheBytes,
    );
  });

  test('configuration is idempotent', () {
    LowMemoryPerformance.configure();
    final cache = PaintingBinding.instance.imageCache;

    expect(cache.maximumSize, 80);
    expect(cache.maximumSizeBytes, 40 * 1024 * 1024);
  });
}
