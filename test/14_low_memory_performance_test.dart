import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:retail_mind/low_memory_performance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runtime font downloads stay off after configure', () {
    LowMemoryPerformance.configure();
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });

  test('decoded image cache is bounded for low-memory devices', () {
    LowMemoryPerformance.configure();
    LowMemoryPerformance.applyDeviceProfile(lowMemory: true);

    final cache = PaintingBinding.instance.imageCache;
    expect(cache.maximumSize, LowMemoryPerformance.lowMemoryMaximumCachedImages);
    expect(
      cache.maximumSizeBytes,
      LowMemoryPerformance.lowMemoryMaximumDecodedImageCacheBytes,
    );
  });

  test('configuration is idempotent', () {
    LowMemoryPerformance.configure();
    LowMemoryPerformance.applyDeviceProfile(lowMemory: true);
    final cache = PaintingBinding.instance.imageCache;

    expect(cache.maximumSize, 16);
    expect(cache.maximumSizeBytes, 8 * 1024 * 1024);
  });

  test('detected device profile can safely restore standard cache limits', () {
    LowMemoryPerformance.configure();
    LowMemoryPerformance.applyDeviceProfile(lowMemory: false);
    final cache = PaintingBinding.instance.imageCache;

    expect(cache.maximumSize, LowMemoryPerformance.maximumCachedImages);
    expect(
      cache.maximumSizeBytes,
      LowMemoryPerformance.maximumDecodedImageCacheBytes,
    );

    LowMemoryPerformance.applyDeviceProfile(lowMemory: true);
    expect(cache.maximumSize, LowMemoryPerformance.lowMemoryMaximumCachedImages);
    expect(
      cache.maximumSizeBytes,
      LowMemoryPerformance.lowMemoryMaximumDecodedImageCacheBytes,
    );
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
