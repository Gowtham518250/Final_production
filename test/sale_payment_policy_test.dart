import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/sale_payment_policy.dart';

void main() {
  group('POS sale payment policy', () {
    test(
      'counts a verified incoming payment even without a bill-match flag',
      () {
        expect(
          SalePaymentPolicy.resolveDetectedReceiptAmount(
            detectedAmount: 45,
            remainingDue: 100,
            isIncomingCredit: true,
            isMerchantConfirmed: true,
            isFailed: false,
            isDuplicate: false,
          ),
          45,
        );
      },
    );

    test('does not apply a likely five-rupee credit before confirmation', () {
      expect(
        SalePaymentPolicy.resolveDetectedReceiptAmount(
          detectedAmount: 5,
          remainingDue: 10,
          isIncomingCredit: true,
          isMerchantConfirmed: false,
          isFailed: false,
          isDuplicate: false,
        ),
        isNull,
      );
    });

    test('caps a verified incoming payment at the remaining due', () {
      expect(
        SalePaymentPolicy.resolveDetectedReceiptAmount(
          detectedAmount: 125,
          remainingDue: 100,
          isIncomingCredit: true,
          isMerchantConfirmed: true,
          isFailed: false,
          isDuplicate: false,
        ),
        100,
      );
    });

    test('does not count pending, outgoing, failed, or duplicate payments', () {
      double? resolve({
        bool incoming = true,
        bool confirmed = true,
        bool failed = false,
        bool duplicate = false,
      }) => SalePaymentPolicy.resolveDetectedReceiptAmount(
        detectedAmount: 45,
        remainingDue: 100,
        isIncomingCredit: incoming,
        isMerchantConfirmed: confirmed,
        isFailed: failed,
        isDuplicate: duplicate,
      );

      expect(resolve(confirmed: false), isNull);
      expect(resolve(incoming: false), isNull);
      expect(resolve(failed: true), isNull);
      expect(resolve(duplicate: true), isNull);
    });

    test(
      'regular cash sale defaults to fully paid when no partial receipt was entered',
      () {
        expect(
          SalePaymentPolicy.resolvePaidAmount(
            totalAmount: 12,
            enteredPaidAmount: 0,
            isBorrow: false,
            isCashPayment: true,
            paymentConfirmed: false,
          ),
          12,
        );
      },
    );

    test('an explicitly recorded partial cash receipt remains partial', () {
      expect(
        SalePaymentPolicy.resolvePaidAmount(
          totalAmount: 100,
          enteredPaidAmount: 30,
          isBorrow: false,
          isCashPayment: true,
          paymentConfirmed: false,
        ),
        30,
      );
    });

    test('confirmed online checkout with no explicit amount is fully paid', () {
      expect(
        SalePaymentPolicy.resolvePaidAmount(
          totalAmount: 85,
          enteredPaidAmount: 0,
          isBorrow: false,
          isCashPayment: false,
          paymentConfirmed: true,
        ),
        85,
      );
    });

    test('unconfirmed online checkout cannot be recorded as paid', () {
      expect(
        SalePaymentPolicy.resolvePaidAmount(
          totalAmount: 85,
          enteredPaidAmount: 0,
          isBorrow: false,
          isCashPayment: false,
          paymentConfirmed: false,
        ),
        0,
      );
    });

    test(
      'borrow invoices stay credit even if an amount was selected elsewhere',
      () {
        expect(
          SalePaymentPolicy.resolvePaidAmount(
            totalAmount: 100,
            enteredPaidAmount: 100,
            isBorrow: true,
            isCashPayment: true,
            paymentConfirmed: true,
          ),
          0,
        );
      },
    );

    test('received amount is never allowed to exceed the invoice total', () {
      expect(
        SalePaymentPolicy.resolvePaidAmount(
          totalAmount: 100,
          enteredPaidAmount: 140,
          isBorrow: false,
          isCashPayment: true,
          paymentConfirmed: false,
        ),
        100,
      );
    });
  });
}
