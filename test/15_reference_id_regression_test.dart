import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/payment_detection_service.dart';

void main() {
  group('reference id extraction', () {
    test('ordinary words are never treated as a UTR', () {
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Transaction successful Rs 150 received',
        ),
        isNull,
      );
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Transaction confirmation for Rs 20 credited',
        ),
        isNull,
      );
    });

    test('real references with digits are still extracted', () {
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Rs 500 credited. UPI Ref No 412345678901',
        ),
        '412345678901',
      );
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Rs 500 received. UTR: AXIS1234567890AB',
        ),
        'AXIS1234567890AB',
      );
    });

    test('a word match does not hide a later real reference', () {
      expect(
        PaymentDetectionService.debugExtractReferenceId(
          'Transaction successful. Rs 75 credited. Ref 987654321012',
        ),
        '987654321012',
      );
    });
  });
}
