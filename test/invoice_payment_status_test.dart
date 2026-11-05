import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/invoice_payment_status.dart';

void main() {
  group('invoicePaymentStatusFor', () {
    test('zero received amount remains unpaid', () {
      expect(invoicePaymentStatusFor(100, 0), 'UNPAID');
    });

    test('positive amount below the balance is partial', () {
      expect(invoicePaymentStatusFor(100, 25), 'PARTIAL');
    });

    test('fully received amount is paid', () {
      expect(invoicePaymentStatusFor(100, 100), 'PAID');
    });

    test('one-paise settlement tolerance is retained for positive receipts', () {
      expect(invoicePaymentStatusFor(100, 99.99), 'PAID');
    });

    test('sub-paise noise rounds to zero and remains unpaid', () {
      expect(invoicePaymentStatusFor(100, 0.004), 'UNPAID');
    });

    test('zero or invalid invoice totals are never marked paid', () {
      expect(invoicePaymentStatusFor(0, 0), 'UNPAID');
      expect(invoicePaymentStatusFor(-10, 5), 'UNPAID');
      expect(invoicePaymentStatusFor(double.nan, 5), 'UNPAID');
    });

    test('overpayment is capped at the invoice total', () {
      expect(invoicePaymentStatusFor(100, 150), 'PAID');
    });
  });
}
