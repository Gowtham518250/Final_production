import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_direction_speech.dart';

void main() {
  group('ownAccountDirection', () {
    test('debit SMS that also mentions the beneficiary credit is a debit', () {
      expect(
        ownAccountDirection(
          'Rs 500 debited from A/c XX1234 on 30-10-26. Credited to ramesh@upi. Ref 412345678901',
        ),
        'debit',
      );
    });

    test('credit to your own account is a credit', () {
      expect(
        ownAccountDirection('Rs 500 credited to your A/c XX1234 by UPI'),
        'credit',
      );
    });

    test('no own-account cue stays unknown', () {
      expect(ownAccountDirection('Payment of Rs 500 processed'), null);
    });

    test('both own-account cues stay unknown (never guess)', () {
      expect(
        ownAccountDirection(
          'Rs 500 credited to your account. Rs 500 debited from A/c XX9999 of Anna',
        ),
        null,
      );
    });

    test('plain debit wording is a debit', () {
      expect(
        ownAccountDirection('INR 250 deducted from your account at Shop'),
        'debit',
      );
    });
  });

  group('neutralPaymentAlert never says money was received', () {
    const forbidden = <String, List<String>>{
      'english': ['received', 'got', 'came', 'arrived'],
      'hindi': ['मिला', 'मिले', 'आया'],
      'tamil': ['வந்தது'],
      'telugu': ['వచ్చింది', 'వచ్చాయÃf'],
      'kannada': ['ಬಂತು', 'ಬಂದಿದೆ'],
      'marathi': ['आले', 'मिळाले'],
      'gujarati': ['મળ્યા'],
      'bengali': ['এসেছে', 'পাওয়া'],
      'punjabi': ['ਮਿਲਿਆ', 'ਮਿਲੇ'],
      'malayalam': ['ലഭിച്ചു'],
    };

    for (final entry in forbidden.entries) {
      test('${entry.key} is direction-neutral', () {
        final text = neutralPaymentAlert(entry.key, '₹500');
        expect(text.isNotEmpty, true);
        expect(text.contains('₹500'), true);
        for (final word in entry.value) {
          expect(text.toLowerCase().contains(word), false);
        }
      });
    }

    test('unknown language falls back to English neutral text', () {
      expect(
        neutralPaymentAlert('klingon', '₹5').contains('credited or debited'),
        true,
      );
    });
  });
}
