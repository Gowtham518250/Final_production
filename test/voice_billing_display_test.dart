import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/voice_billing_display.dart';

const _langs = ['te', 'hi', 'ta', 'kn', 'ml', 'mr', 'bn', 'gu', 'pa'];

void main() {
  group('product names (display only)', () {
    test('items from the screenshot', () {
      expect(VoiceBillingDisplay.productName('Chicken Biryani', 'te'), 'చికెన్ బిర్యానీ');
      expect(VoiceBillingDisplay.productName('Mutton Biryani', 'te'), 'మటన్ బిర్యానీ');
    });

    test('every supported language gives a non-English result', () {
      for (final lang in _langs) {
        final t = VoiceBillingDisplay.productName('Chicken Biryani', lang);
        expect(t != null, true);
        expect(RegExp(r'[A-Za-z]').hasMatch(t!), false);
      }
    });

    test('language code forms te, te-IN, te_IN all work', () {
      for (final code in ['te', 'te-IN', 'te_IN', 'TE']) {
        expect(VoiceBillingDisplay.productName('Milk', code), 'పాలు');
      }
    });

    test('plurals, spelling variants and quantities', () {
      expect(VoiceBillingDisplay.productName('Eggs', 'hi'), 'अंडा');
      expect(VoiceBillingDisplay.productName('Chicken Biriyani', 'hi'), 'चिकन बिरयानी');
      expect(VoiceBillingDisplay.productName('Milk 500ml', 'te'), 'పాలు 500ml');
    });

    test('an unknown English word is never half-translated (returns null)', () {
      expect(VoiceBillingDisplay.productName('Panchedar', 'te'), null);
      expect(VoiceBillingDisplay.productName('Sunflower Oil', 'te'), null);
    });

    test('English and unsupported languages are not translated', () {
      expect(VoiceBillingDisplay.productName('Milk', 'en'), null);
      expect(VoiceBillingDisplay.productName('Milk', 'fr'), null);
    });

    test('empty input is safe', () {
      expect(VoiceBillingDisplay.productName('', 'te'), null);
      expect(VoiceBillingDisplay.productName('   ', 'te'), null);
    });

    test('the canonical name is a pure input: calling never changes it', () {
      const canonical = 'Mutton Biryani';
      VoiceBillingDisplay.productName(canonical, 'te');
      expect(canonical, 'Mutton Biryani');
    });
  });

  group('units', () {
    test('known units', () {
      expect(VoiceBillingDisplay.unit('kg', 'te'), 'కిలో');
      expect(VoiceBillingDisplay.unit('pc', 'te'), 'పీస్');
      expect(VoiceBillingDisplay.unit('L', 'hi'), 'लीटर');
      expect(VoiceBillingDisplay.unit('mL', 'ta'), 'மி.லி');
    });

    test('aliases and case', () {
      expect(VoiceBillingDisplay.unit('Kilo', 'te'), 'కిలో');
      expect(VoiceBillingDisplay.unit('PCS', 'te'), 'పీస్');
      expect(VoiceBillingDisplay.unit('litre', 'kn'), 'ಲೀಟರ್');
    });

    test('unknown unit and English are returned unchanged', () {
      expect(VoiceBillingDisplay.unit('bundle', 'te'), 'bundle');
      expect(VoiceBillingDisplay.unit('kg', 'en'), 'kg');
    });
  });

  group('warnings', () {
    const customPriced =
        '"Chicken Biryani" is not in this shop catalogue. It can be billed as a custom item with no stock deduction; verify its name and price.';

    test('the exact sentence from the screenshot becomes Telugu', () {
      final t = VoiceBillingDisplay.warning(customPriced, 'te');
      expect(t != null, true);
      expect(t!.contains('చికెన్ బిర్యానీ'), true); // name localised too
      expect(t.contains('shop catalogue'), false);
      expect(t.contains('కేటలాగ్'), true);
    });

    test('every supported language localises every known sentence', () {
      final samples = <String>[
        customPriced,
        '"Panchedar" is not in this shop catalogue and no price was detected. Review the name and enter a selling price; no stock will be deducted.',
        'Please repeat or manually select "Oil"; I could not safely verify it.',
        'The AI product name "Rice" conflicts with its catalogue ID. It was not linked to inventory; confirm the exact item manually. No stock will be deducted.',
        'The AI returned an unknown catalogue ID for "Rice". Select the correct item manually; no stock will be deducted.',
        'A spoken hundred-scale amount was normalized. Verify the product and price before adding it to the bill.',
        'Corrected a spoken hundred-scale amount using the local shop catalogue. Review each item before billing.',
        'Spoken amount "రేణు ఉందలు" was read as 200. Please verify.',
        'Groq could not verify this voice request. No items were auto-added; retry or enter the sale manually.',
        'Groq voice billing is not configured on the backend. Set GROQ_API_KEY in Render → Environment, then retry. No items were added.',
        'Groq is unreachable. Review every item name and price before billing; unlisted items will be added as custom lines without stock deduction.',
        'I could not confidently identify bill items. Please review the transcript.',
        'Voice processing failed. Please retry.',
        'Enter a positive selling price for "Sugar" before adding it to the bill.',
        'Review "Sugar" and its price before adding it as a custom bill item.',
        'Custom bill item: no inventory stock will be deducted.',
        'Price recovered from the normalized spoken amount. Verify before billing.',
      ];
      for (final lang in _langs) {
        for (final s in samples) {
          final t = VoiceBillingDisplay.warning(s, lang);
          expect(t != null, true);
          expect(t!.contains('{name}') || t.contains('{value}'), false);
          expect(t.contains('catalogue'), false);
          expect(t.contains('Groq'), false); // developer wording never reaches the shopkeeper
        }
      }
    });

    test('the heard words and the repaired number are filled in', () {
      final t = VoiceBillingDisplay.warning('Spoken amount "రేణు ఉందలు" was read as 200. Please verify.', 'te')!;
      expect(t.contains('రేణు ఉందలు'), true);
      expect(t.contains('200'), true);
    });

    test('an unknown sentence returns null so the translator can try', () {
      expect(VoiceBillingDisplay.warning('Something completely new happened.', 'te'), null);
    });

    test('English is left alone', () {
      expect(VoiceBillingDisplay.warning(customPriced, 'en'), null);
    });
  });

  group('dictionary integrity', () {
    test('every product word has a result for every language', () {
      const words = [
        'chicken', 'mutton', 'fish', 'egg', 'biryani', 'rice', 'sugar', 'salt', 'oil', 'milk', 'curd',
        'tea', 'coffee', 'wheat', 'flour', 'dal', 'onion', 'potato', 'tomato', 'ghee', 'butter', 'bread',
        'biscuit', 'soap', 'water', 'juice', 'paneer', 'masala', 'chilli', 'turmeric', 'ginger', 'garlic',
        'banana', 'apple', 'coconut', 'idli', 'dosa',
      ];
      for (final lang in _langs) {
        for (final w in words) {
          final t = VoiceBillingDisplay.productName(w, lang);
          expect(t != null && t.trim().isNotEmpty, true);
        }
      }
    });

    test('every unit has a result for every language', () {
      for (final lang in _langs) {
        for (final u in ['kg', 'g', 'L', 'mL', 'pc', 'pkt', 'btl', 'box', 'doz']) {
          expect(VoiceBillingDisplay.unit(u, lang) != u, true);
        }
      }
    });
  });
}
