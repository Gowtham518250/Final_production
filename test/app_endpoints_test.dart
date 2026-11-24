import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/app_endpoints.dart';

void main() {
  test('normalizes configured hosts without duplicate trailing slashes', () {
    expect(
      AppEndpoints.normalizeBaseUrl('  api.example.test/// '),
      'https://api.example.test',
    );
    expect(
      AppEndpoints.normalizeBaseUrl('wss://api.example.test/ws/'),
      'wss://api.example.test/ws',
    );
  });

  test(
    'delivery socket is derived from the configured customer socket host',
    () {
      expect(
        AppEndpoints.deliveryTrackingWebSocketUrl,
        '${AppEndpoints.customerWebSocketBaseUrl}/delivery/track',
      );
    },
  );

  test('builds a shop-specific customer storefront URL', () {
    expect(
      AppEndpoints.customerStoreBaseUrl,
      'https://retail-mind-1-8fpk.onrender.com',
    );
    expect(
      AppEndpoints.customerShopUrl(42),
      'https://retail-mind-1-8fpk.onrender.com/shop/42',
    );
    expect(() => AppEndpoints.customerShopUrl(0), throwsArgumentError);
  });

  test('printer order contact is absent unless configured', () {
    expect(AppEndpoints.printerOrderWhatsapp, isNull);
  });
}
