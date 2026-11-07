import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/pos_checkout_status.dart';

void main() {
  test('online checkout stays waiting until confirmed', () {
    expect(
      PosCheckoutStatus.lane(
        isOnlinePayment: true,
        paymentConfirmed: false,
        cashierManualOverride: false,
        isBorrow: false,
        paidAmount: 0,
        totalAmount: 100,
      ),
      PosPaymentLane.waiting,
    );
  });

  test('cashier override is never shown as paid UPI', () {
    expect(
      PosCheckoutStatus.label(
        PosCheckoutStatus.lane(
          isOnlinePayment: true,
          paymentConfirmed: true,
          cashierManualOverride: true,
          isBorrow: false,
          paidAmount: 100,
          totalAmount: 100,
        ),
      ),
      'Cashier override',
    );
  });
}
