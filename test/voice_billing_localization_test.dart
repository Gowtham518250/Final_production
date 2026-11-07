import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/voice_billing_localization.dart';

void main() {
  group('VoiceBillingLocalization', () {
    test('uses curated Telugu labels without a network translation', () {
      expect(
        VoiceBillingLocalization.label('What I heard', 'te'),
        'మీరు చెప్పింది',
      );
      expect(
        VoiceBillingLocalization.label('Detected items', 'te-IN'),
        'గుర్తించిన వస్తువులు',
      );
      expect(
        VoiceBillingLocalization.label('PRODUCT NAMES', 'te'),
        'వస్తువుల పేర్లు',
      );
    });

    test('uses the selected Hindi and Tamil labels', () {
      expect(
        VoiceBillingLocalization.label('What I heard', 'hi'),
        'मैंने क्या सुना',
      );
      expect(
        VoiceBillingLocalization.label('AI understood', 'ta'),
        'AI புரிந்துகொண்டது',
      );
    });

    test('falls back to English copy for supported keys and preserves unknown copy', () {
      expect(
        VoiceBillingLocalization.label('Detected items', 'unknown'),
        'Detected items',
      );
      expect(
        VoiceBillingLocalization.label('A new message', 'te'),
        'A new message',
      );
    });
  });

  group('placeholder labels for sales entry', () {
    const placeholders = [
      'Product Name', 'Qty', 'Price', 'Disc (₹)', 'GST %', 'Phone Number', 'Customer Name',
    ];
    const langs = ['te', 'hi', 'ta', 'kn', 'ml', 'mr', 'bn', 'gu', 'pa'];

    test('English placeholders are unchanged', () {
      for (final key in placeholders) {
        expect(VoiceBillingLocalization.label(key, 'en'), key);
      }
    });

    test('every placeholder is localised in every supported language', () {
      for (final lang in langs) {
        for (final key in placeholders) {
          final t = VoiceBillingLocalization.label(key, lang);
          // GST % legitimately keeps its Latin letters.
          if (key == 'GST %') continue;
          expect(t != key, true);
        }
      }
    });

    test('regional locale codes resolve', () {
      expect(VoiceBillingLocalization.label('Price', 'te-IN'), 'ధర');
      expect(VoiceBillingLocalization.label('Qty', 'te_IN'), 'పరిమాణం');
    });

    test('an unknown key falls back to itself, an unknown language to English', () {
      expect(VoiceBillingLocalization.label('Something else', 'te'), 'Something else');
      expect(VoiceBillingLocalization.label('Price', 'xx'), 'Price');
    });
});
}
