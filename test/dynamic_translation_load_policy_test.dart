import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/dynamic_translation_load_policy.dart';

void main() {
  group('DynamicTranslationLoadPolicy', () {
    test('bounds pending unique translations on low-end devices', () {
      expect(DynamicTranslationLoadPolicy.maxPending(lowEndDevice: true), 12);
      expect(
        DynamicTranslationLoadPolicy.shouldAccept(
          pendingUniqueRequests: 11,
          lowEndDevice: true,
        ),
        isTrue,
      );
      expect(
        DynamicTranslationLoadPolicy.shouldAccept(
          pendingUniqueRequests: 12,
          lowEndDevice: true,
        ),
        isFalse,
      );
    });

    test('allows a larger queue on standard devices', () {
      expect(
        DynamicTranslationLoadPolicy.maxPending(lowEndDevice: false),
        240,
      );
      expect(
        DynamicTranslationLoadPolicy.shouldAccept(
          pendingUniqueRequests: 239,
          lowEndDevice: false,
        ),
        isTrue,
      );
      expect(
        DynamicTranslationLoadPolicy.shouldAccept(
          pendingUniqueRequests: 240,
          lowEndDevice: false,
        ),
        isFalse,
      );
    });

    test('rejects invalid pending counts', () {
      expect(
        DynamicTranslationLoadPolicy.shouldAccept(
          pendingUniqueRequests: -1,
          lowEndDevice: true,
        ),
        isFalse,
      );
    });
  });
}
