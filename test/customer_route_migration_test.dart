import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/screens/customer/customer_home_page.dart';
import 'package:retail_mind/screens/customer/customer_login_page.dart';
import 'package:retail_mind/screens/customer/customer_marketplace_page.dart';
import 'package:retail_mind/screens/customer/nearby_shops_page.dart';
import 'package:retail_mind/screens/customer/order_history_page.dart';
import 'package:retail_mind/shop_browser_page.dart';

void main() {
  test('removed owner-app customer pages are gone from lib/', () {
    const removed = [
      'lib/customer_login_page.dart',
      'lib/customer_dashboard_page.dart',
      'lib/customer_register_page.dart',
      'lib/expense_page.dart',
      'lib/llm_nlp_fallback_service.dart',
    ];
    for (final path in removed) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    expect(File('lib/screens/customer/customer_login_page.dart').existsSync(), isTrue);
  });

  test('replacement customer screens still exist', () {
    expect(const CustomerLoginPage(), isA<CustomerLoginPage>());
    expect(const CustomerMarketplacePage(), isA<CustomerMarketplacePage>());
    expect(const CustomerHomePage(), isA<CustomerHomePage>());
    expect(const NearbyShopsPage(), isA<NearbyShopsPage>());
    expect(const OrderHistoryPage(), isA<OrderHistoryPage>());
    expect(const ShopBrowserPage(), isA<ShopBrowserPage>());
  });
}
