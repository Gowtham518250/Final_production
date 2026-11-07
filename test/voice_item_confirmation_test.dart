import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/voice_billing_assistant.dart';
import 'package:retail_mind/voice_item_confirmation.dart';
import 'package:retail_mind/voice_nlp_engine.dart';

void main() {
  test('low-confidence lines are not auto-confirmed without a catalog match', () {
    expect(
      VoiceItemConfirmation.shouldAutoConfirm(
        confidence: 0.4,
        catalogMatched: false,
      ),
      isFalse,
    );
    expect(
      VoiceItemConfirmation.shouldAutoConfirm(
        confidence: 0.7,
        catalogMatched: false,
      ),
      isTrue,
    );
    expect(
      VoiceItemConfirmation.shouldAutoConfirm(
        confidence: 0.2,
        catalogMatched: true,
      ),
      isTrue,
    );
  });

  test('ambiguous name-plus-number speech stays unconfirmed for review', () {
    expect(
      VoiceItemConfirmation.shouldAutoConfirm(
        confidence: 0.9,
        catalogMatched: true,
        quantityPriceAmbiguous: true,
      ),
      isFalse,
    );

    final parsed = VoiceNlpEngineV2.parse(
      'rice 60',
      'en',
      catalog: [
        {'name': 'Rice', 'price': '60'},
      ],
    );
    expect(parsed, isNotEmpty);
    expect(parsed.first.quantityPriceAmbiguous, isTrue);
    expect(parsed.first.isConfirmed, isFalse);
  });

  test('assistant parser uses the same confirmation helper', () {
    final item = ParsedItem(
      name: 'Rice',
      qty: 1,
      unit: 'pc',
      price: 60,
      confidence: 0.9,
      catalogMatched: true,
      quantityPriceAmbiguous: true,
    );
    expect(item.isConfirmed, isFalse);
  });

  test('explicit quantity and price can auto-confirm when confidence is high', () {
    final parsed = VoiceNlpEngineV2.parse(
      '2 kg rice 50',
      'en',
      catalog: [
        {'name': 'Rice', 'price': '50'},
      ],
    );
    expect(parsed, isNotEmpty);
    expect(parsed.first.quantityPriceAmbiguous, isFalse);
    expect(parsed.first.qty, 2);
    expect(parsed.first.price, 50);
  });
}
