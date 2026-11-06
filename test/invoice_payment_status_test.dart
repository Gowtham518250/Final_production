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

    test(
      'one-paise settlement tolerance is retained for positive receipts',
      () {
        expect(invoicePaymentStatusFor(100, 99.99), 'PAID');
      },
    );

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

    test('reconciles a paid invoice into its stale unpaid sales mirror', () {
      final merged = mergeInvoicePaymentState(
        {
          'invoice_number': 'BILL-204',
          'total_amount': 400.0,
          'paid_amount': 0.0,
          'payment_status': 'UNPAID',
          'status': 'UNPAID',
        },
        {
          'invoice_number': 'BILL-204',
          'total_amount': 400.0,
          'payment_status': 'PAID',
          'paid_amount': 400.0,
        },
      );

      expect(merged['paid_amount'], 400.0);
      expect(merged['payment_status'], 'PAID');
      expect(merged['status'], 'PAID');
      expect(merged['pending_amount'], 0.0);
    });

    test('uses the paid status when the server omits the paid amount', () {
      final merged = mergeInvoicePaymentState(
        {'total_amount': 400.0, 'payment_status': 'UNPAID'},
        {'total_amount': 400.0, 'payment_status': 'PAID'},
      );

      expect(merged['paid_amount'], 400.0);
      expect(merged['payment_status'], 'PAID');
    });

    test(
      'does not downgrade a locally paid invoice from a stale backend row',
      () {
        final merged = mergeInvoicePaymentState(
          {'total_amount': 400.0, 'payment_status': 'PAID', 'status': 'PAID'},
          {
            'total_amount': 400.0,
            'paid_amount': 0.0,
            'payment_status': 'UNPAID',
          },
        );

        expect(merged['paid_amount'], 400.0);
        expect(merged['payment_status'], 'PAID');
      },
    );

    test('does not treat an order status as a payment status', () {
      final current = {
        'total_amount': 400.0,
        'paid_amount': 0.0,
        'payment_status': 'UNPAID',
      };

      expect(
        mergeInvoicePaymentState(current, {'status': 'PROCESSING'}),
        current,
      );
    });

    test('counts three distinct partial payments cumulatively', () {
      var invoice = <String, dynamic>{
        'invoice_number': 'BILL-305',
        'total_amount': 100.0,
        'paid_amount': 0.0,
        'payment_status': 'UNPAID',
      };

      for (var index = 1; index <= 3; index++) {
        final updated = applyInvoicePaymentOnce(
          invoice,
          amount: 10,
          idempotencyKey: 'payment_$index',
        );
        expect(updated, isNotNull);
        invoice = updated!;
      }

      expect(invoice['paid_amount'], 30.0);
      expect(invoice['pending_amount'], 70.0);
      expect(invoice['payment_status'], 'PARTIAL');
    });

    test('replaying the same partial payment does not increase paid total', () {
      final first = applyInvoicePaymentOnce(
        {
          'invoice_number': 'BILL-306',
          'total_amount': 100.0,
          'paid_amount': 0.0,
        },
        amount: 10,
        idempotencyKey: 'detected_utr_same-transfer',
      );
      final replay = applyInvoicePaymentOnce(
        first!,
        amount: 10,
        idempotencyKey: 'detected_utr_same-transfer',
      );

      expect(replay, isNull);
      expect(first['paid_amount'], 10.0);
      expect(first['pending_amount'], 90.0);
    });

    test('does not assign an unlinked payment to the only open invoice', () {
      final onlyOpenInvoice = <Map<String, dynamic>>[
        {
          'invoice_id': 42,
          'invoice_number': 'BILL-307',
          'total_amount': 100.0,
          'paid_amount': 0.0,
          'payment_status': 'UNPAID',
        },
      ];

      expect(
        findInvoiceByExplicitPaymentReference(onlyOpenInvoice, null),
        isNull,
      );
      expect(
        findInvoiceByExplicitPaymentReference(onlyOpenInvoice, ''),
        isNull,
      );
      expect(
        findInvoiceByExplicitPaymentReference(onlyOpenInvoice, 'bill-307'),
        same(onlyOpenInvoice.single),
      );
    });
  });
}
