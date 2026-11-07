import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/screens/customer/cart_checkout_page.dart';

void main() {
  test('cart subtotal accepts string price and qty from JSON', () {
    final total = cartItemsSubtotal([
      {'price': '25.50', 'qty': '2'},
      {'unit_price': 10, 'quantity': '1.5'},
    ]);
    expect(total, 66.0);
  });

  test('cart subtotal ignores invalid rows instead of throwing', () {
    expect(
      cartItemsSubtotal([
        {'price': 'abc', 'qty': 2},
        {'price': 5, 'qty': null},
      ]),
      0,
    );
  });

  test('UPI checkout stays pending until a matching confirmation', () {
    expect(customerCheckoutPaymentStatus('upi'), 'pending');
    expect(customerCheckoutPaymentStatus('cod'), 'cod');
  });
}
