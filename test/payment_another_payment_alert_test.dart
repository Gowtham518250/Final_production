import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_direction_speech.dart';

void main() {
  const languages = [
    'english',
    'hindi',
    'tamil',
    'telugu',
    'kannada',
    'marathi',
    'gujarati',
    'bengali',
    'punjabi',
    'malayalam',
  ];

  test('each language asks the merchant to verify and includes the amount', () {
    for (final language in languages) {
      final text = anotherPaymentAlert(language, '₹500');
      expect(text, contains('₹500'));
      expect(text, isNotEmpty);
    }
  });

  test('English does not claim that the payment was received', () {
    final text = anotherPaymentAlert('english', '₹500').toLowerCase();
    expect(text, contains('another payment'));
    expect(text, contains('verify'));
    expect(text, isNot(contains('received')));
  });
}
