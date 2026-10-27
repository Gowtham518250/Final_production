import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/growth_marketing_helpers.dart';

void main() {
  test('English copy uses only the supplied offer and real product details', () {
    final caption = GrowthAdCopy.caption(
      shopName: 'Green Basket',
      goal: 'new_product',
      language: 'en',
      productName: 'Rice',
      price: 55,
      offer: '',
      offerCode: 'RM123456',
    );

    expect(caption, contains('Green Basket'));
    expect(caption, contains('Rice'));
    expect(caption, contains('₹55'));
    expect(caption, isNot(contains('RM123456')));
    expect(caption, isNot(contains('%')));
    expect(caption, isNot(contains('discount')));
  });

  test('Telugu and Hindi copy use their selected language', () {
    final telugu = GrowthAdCopy.caption(
      shopName: 'మన షాప్',
      goal: 'nearby',
      language: 'te',
      offerCode: 'RM123456',
    );
    final hindi = GrowthAdCopy.caption(
      shopName: 'अपनी दुकान',
      goal: 'nearby',
      language: 'hi',
      offerCode: 'RM123456',
    );

    expect(telugu, contains('మీ దగ్గరలోని'));
    expect(telugu, isNot(contains('RM123456')));
    expect(hindi, contains('आपकी भरोसेमंद'));
    expect(hindi, isNot(contains('RM123456')));
  });

  test('offer codes have a stable prefix and six-character suffix', () {
    final code = GrowthAdCopy.offerCode(DateTime(2026, 10, 27));
    expect(code, matches(RegExp(r'^RM[0-9]{6}$')));
  });

  test('an owner-entered offer is included but never fabricated', () {
    final withoutOffer = GrowthAdCopy.caption(
      shopName: 'Corner Store',
      goal: 'nearby',
      language: 'en',
      offerCode: 'RM000001',
    );
    final withOffer = GrowthAdCopy.caption(
      shopName: 'Corner Store',
      goal: 'nearby',
      language: 'en',
      offer: '10% off on rice today',
      offerCode: 'RM000001',
    );

    expect(withoutOffer, isNot(contains('Offer:')));
    expect(withoutOffer, isNot(contains('RM000001')));
    expect(withOffer, contains('Offer: 10% off on rice today'));
    expect(withOffer, contains('RM000001'));
  });
}
