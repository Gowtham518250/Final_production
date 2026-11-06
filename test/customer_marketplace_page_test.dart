import 'package:flutter_test/flutter_test.dart';

import 'package:retail_mind/screens/customer/customer_marketplace_page.dart';
import 'package:retail_mind/screens/customer/shop_locations_map.dart';

void main() {
  test('marketplace page remains a constructible customer entry point', () {
    expect(const CustomerMarketplacePage(), isA<CustomerMarketplacePage>());
  });

  test('map only includes shops with valid real coordinates', () {
    final mapped = ShopLocationsMap.shopsWithCoordinates([
      {'shop_name': 'Mapped', 'latitude': 17.4, 'longitude': 78.4},
      {'shop_name': 'Address only', 'address': 'Main Road'},
      {'shop_name': 'Invalid', 'latitude': 120, 'longitude': 78.4},
    ]);

    expect(mapped.map((shop) => shop['shop_name']), ['Mapped']);
  });
}
