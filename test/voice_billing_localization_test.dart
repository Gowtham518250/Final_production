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
}
