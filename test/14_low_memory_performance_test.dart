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

    expect(cache.maximumSize, 48);
    expect(cache.maximumSizeBytes, 24 * 1024 * 1024);
  });

  test('decode dimensions respect display scale and memory bounds', () {
    expect(
      LowMemoryPerformance.decodeCacheDimension(
        50,
        3,
        minPixels: 100,
        maxPixels: 240,
      ),
      150,
    );
    expect(
      LowMemoryPerformance.decodeCacheDimension(
        500,
        3,
        minPixels: 320,
        maxPixels: 640,
      ),
      640,
    );
    expect(
      LowMemoryPerformance.decodeCacheDimension(
        20,
        2,
        minPixels: 100,
        maxPixels: 240,
      ),
      100,
    );
  });

  test('decode dimension rejects invalid inputs', () {
    expect(
      () => LowMemoryPerformance.decodeCacheDimension(0, 3),
      throwsArgumentError,
    );
    expect(
      () => LowMemoryPerformance.decodeCacheDimension(
        50,
        3,
        minPixels: 300,
        maxPixels: 200,
      ),
      throwsArgumentError,
    );
  });
}
