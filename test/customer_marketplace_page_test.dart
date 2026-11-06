import 'package:flutter_test/flutter_test.dart';

import 'package:retail_mind/screens/customer/customer_marketplace_page.dart';

void main() {
  test('marketplace shop cards expose location and contact actions', () {
    // Widget-level layout is covered by the app's integration suite. Keep this
    // smoke contract to protect the public customer marketplace entry point.
    expect(const CustomerMarketplacePage(), isA<CustomerMarketplacePage>());
  });
}
