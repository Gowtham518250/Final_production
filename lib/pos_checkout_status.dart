import 'sale_payment_policy.dart';

enum PosPaymentLane {
  cashReady,
  waiting,
  partial,
  paid,
  credit,
  cashierOverride,
}

class PosCheckoutStatus {
  static PosPaymentLane lane({
    required bool isOnlinePayment,
    required bool paymentConfirmed,
    required bool cashierManualOverride,
    required bool isBorrow,
    required double paidAmount,
    required double totalAmount,
  }) {
    if (isBorrow) return PosPaymentLane.credit;
    if (cashierManualOverride) return PosPaymentLane.cashierOverride;
    if (SalePaymentPolicy.isPartialPaid(paidAmount, totalAmount)) {
      return PosPaymentLane.partial;
    }
    if (paymentConfirmed ||
        (!isOnlinePayment &&
            SalePaymentPolicy.isFullyPaid(
              paidAmount > 0 ? paidAmount : totalAmount,
              totalAmount,
            ))) {
      return isOnlinePayment ? PosPaymentLane.paid : PosPaymentLane.cashReady;
    }
    if (isOnlinePayment) return PosPaymentLane.waiting;
    return PosPaymentLane.cashReady;
  }

  static String label(PosPaymentLane lane) {
    switch (lane) {
      case PosPaymentLane.cashReady:
        return 'Cash ready';
      case PosPaymentLane.waiting:
        return 'Waiting';
      case PosPaymentLane.partial:
        return 'Partial';
      case PosPaymentLane.paid:
        return 'Paid';
      case PosPaymentLane.credit:
        return 'Credit';
      case PosPaymentLane.cashierOverride:
        return 'Cashier override';
    }
  }
}
