import 'package:flutter_test/flutter_test.dart';
import '../lib/payment_alert_policy.dart';

void main() {
  group('shouldUseAudiblePaymentAlert', () {
    test('verification-required credit is audible even when voice is enabled', () {
      expect(
        shouldUseAudiblePaymentAlert(
          isLate: false,
          voiceEnabled: true,
          hasConflict: false,
          needsVerification: true,
        ),
        isTrue,
      );
    });

    test('late and conflicting payment alerts remain audible', () {
      expect(
        shouldUseAudiblePaymentAlert(
          isLate: true,
          voiceEnabled: true,
          hasConflict: false,
          needsVerification: false,
        ),
        isTrue,
      );
      expect(
        shouldUseAudiblePaymentAlert(
          isLate: false,
          voiceEnabled: true,
          hasConflict: true,
          needsVerification: false,
        ),
        isTrue,
      );
    });

    test('verified normal payment can keep a silent notification with TTS', () {
      expect(
        shouldUseAudiblePaymentAlert(
          isLate: false,
          voiceEnabled: true,
          hasConflict: false,
          needsVerification: false,
        ),
        isFalse,
      );
    });

    test('payment notification is audible when voice is disabled', () {
      expect(
        shouldUseAudiblePaymentAlert(
          isLate: false,
          voiceEnabled: false,
          hasConflict: false,
          needsVerification: false,
        ),
        isTrue,
      );
    });
  });
}
