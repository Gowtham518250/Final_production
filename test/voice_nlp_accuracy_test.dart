import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retail_mind/product_catalog_service.dart';
import 'package:retail_mind/production_voice_billing_service.dart';
import 'package:retail_mind/voice_nlp_engine.dart';

/// Regression tests for voice-billing accuracy bugs in the NLP engine:
///  - canonical units ('kg', 'g', 'l', plurals) were not recognised, so
///    "2 kg rice 50" became product "Kg Rice" with unit 'pc'
///  - every '.' split the transcript, so "0.5 kg rice 50" billed 5 kg
///  - "gm" was stripped as a filler, so "500 gm sugar" billed 500 pieces
///  - "rs" was stripped from inside words ("wafers" -> "wafe")
void main() {
  group('VoiceNlpEngineV2 units', () {
    test('recognises "kg" as a unit instead of part of the product name', () {
      final items = VoiceNlpEngineV2.parse('2 kg rice 50', 'en-IN');
      expect(items, hasLength(1));
      final item = items.single;
      expect(item.qty, 2);
      expect(item.unit, 'kg');
      expect(item.unitWasSpoken, isTrue);
      expect(item.price, 50);
      expect(item.name.toLowerCase(), contains('rice'));
      expect(item.name.toLowerCase(), isNot(contains('kg')));
    });

    test('keeps "gm" as grams rather than stripping it', () {
      final items = VoiceNlpEngineV2.parse('500 gm sugar 25', 'en-IN');
      expect(items, hasLength(1));
      expect(items.single.qty, 500);
      expect(items.single.unit, 'g');
      expect(items.single.name.toLowerCase(), contains('sugar'));
      expect(items.single.price, 25);
    });

    test('recognises plural unit words', () {
      final items = VoiceNlpEngineV2.parse('3 packets biscuit 100', 'en-IN');
      expect(items, hasLength(1));
      expect(items.single.qty, 3);
      expect(items.single.unit, 'pkt');
      expect(items.single.name.toLowerCase(), contains('biscuit'));
      expect(items.single.price, 100);
    });

    test('marks the unit as not spoken when the cashier did not say one', () {
      final items = VoiceNlpEngineV2.parse('rice 50', 'en-IN');
      expect(items, hasLength(1));
      expect(items.single.unitWasSpoken, isFalse);
    });

    test('UnitNormalizer treats canonical short forms as units', () {
      for (final unit in ['kg', 'g', 'l', 'ml', 'pkt', 'btl', 'doz']) {
        expect(UnitNormalizer.isUnit(unit), isTrue, reason: unit);
      }
      expect(UnitNormalizer.normalize('l'), 'L');
      expect(UnitNormalizer.normalize('packets'), 'pkt');
      expect(UnitNormalizer.isUnit('rice'), isFalse);
    });
  });

  group('VoiceNlpEngineV2 decimals and separators', () {
    test('does not split a decimal quantity at the dot', () {
      final items = VoiceNlpEngineV2.parse('0.5 kg rice 50', 'en-IN');
      expect(items, hasLength(1));
      expect(items.single.qty, 0.5);
      expect(items.single.unit, 'kg');
      expect(items.single.price, 50);
    });

    test('parses decimal and whole quantities in one command', () {
      final items = VoiceNlpEngineV2.parse(
        '1.5 kg sugar 60 and 2 kg rice 50',
        'en-IN',
      );
      expect(items, hasLength(2));
      expect(items[0].qty, 1.5);
      expect(items[0].name.toLowerCase(), contains('sugar'));
      expect(items[1].qty, 2);
      expect(items[1].name.toLowerCase(), contains('rice'));
    });

    test('still splits two items separated by a sentence-ending dot', () {
      final items = VoiceNlpEngineV2.parse('rice 50. sugar 60', 'en-IN');
      expect(items, hasLength(2));
      expect(items[0].name.toLowerCase(), contains('rice'));
      expect(items[0].price, 50);
      expect(items[1].name.toLowerCase(), contains('sugar'));
      expect(items[1].price, 60);
    });

    test('treats "Rs." as a currency marker, not an item separator', () {
      final items = VoiceNlpEngineV2.parse('rice Rs. 50', 'en-IN');
      expect(items, hasLength(1));
      expect(items.single.price, 50);
      expect(items.single.qty, 1);
    });
  });

  group('VoiceNlpEngineV2 currency stripping', () {
    test('does not remove "rs" from inside a product name', () {
      final items = VoiceNlpEngineV2.parse('2 wafers 30', 'en-IN');
      expect(items, hasLength(1));
      expect(items.single.name.toLowerCase(), contains('wafers'));
      expect(items.single.qty, 2);
      expect(items.single.price, 30);
    });
  });

  group('ProductionVoiceBillingService units', () {
    late ProductCatalogService catalog;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      catalog = ProductCatalogService();
      await catalog.load([
        {'name': 'Rice', 'price': 50, 'unit': 'pkt'},
        {'name': 'Sugar', 'price': 60, 'unit': 'pkt'},
      ]);
    });

    test('a spoken unit wins over the catalog unit', () async {
      final result = await ProductionVoiceBillingService.parse(
        transcript: '2 kg rice 50',
        localeCode: 'en-IN',
        catalogService: catalog,
        knownProducts: const [
          {'name': 'Rice', 'price': 50, 'unit': 'pkt'},
        ],
      );

      expect(result.lines, hasLength(1));
      expect(result.lines.single.name, 'Rice');
      expect(result.lines.single.quantity, 2);
      expect(result.lines.single.unit, 'kg');
      expect(result.lines.single.price, 50);
    });

    test('uses the shop catalog unit when no unit was spoken', () async {
      final result = await ProductionVoiceBillingService.parse(
        transcript: 'sugar 60',
        localeCode: 'en-IN',
        catalogService: catalog,
        knownProducts: const [
          {'name': 'Sugar', 'price': 60, 'unit': 'pkt'},
        ],
      );

      expect(result.lines, hasLength(1));
      expect(result.lines.single.name, 'Sugar');
      expect(result.lines.single.unit, 'pkt');
      expect(result.lines.single.price, 60);
    });
  });
}
