import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/bill_generator_service.dart';

void main() {
  test('shared bill copy contains the shop name and no unrelated brand', () {
    final message = BillGeneratorService.buildShareMessage(
      customerName: 'Asha',
      shopName: 'Green Basket',
    );

    expect(message, contains('Dear Asha'));
    expect(message, contains('at Green Basket'));
    expect(message, isNot(contains('AI Shop Pro')));
    expect(message, isNot(contains('aishoppro.com')));
  });

  test('shared bill copy works without customer or shop details', () {
    expect(
      BillGeneratorService.buildShareMessage(),
      'Thank you for shopping with us!\nPlease find your digital bill attached.',
    );
  });
}
