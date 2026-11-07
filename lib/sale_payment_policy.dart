import 'dart:math' as math;

/// Resolves payment state for a sale submitted from the POS.
///
/// A regular cash sale is paid in full when no separate partial receipt was
/// entered. Explicit partial receipts remain partial. Borrow invoices are
/// recorded through the credit workflow and must not be treated as collected.
class SalePaymentPolicy {
  /// One paisa. Wide enough for float noise, not wide enough to forgive a short payment.
  static const double paisa = 0.01;

  static int toPaise(double value) => (value * 100).round();

  static bool isFullyPaid(double paidAmount, double totalAmount) {
    if (!paidAmount.isFinite || !totalAmount.isFinite) return false;
    if (totalAmount <= 0) return paidAmount >= 0;
    return toPaise(paidAmount) >= toPaise(totalAmount);
  }

  static bool isPartialPaid(double paidAmount, double totalAmount) {
    if (!paidAmount.isFinite || !totalAmount.isFinite) return false;
    return toPaise(paidAmount) > 0 && !isFullyPaid(paidAmount, totalAmount);
  }

  static double remainingDue(double paidAmount, double totalAmount) {
    if (!paidAmount.isFinite || !totalAmount.isFinite) return 0;
    final remainingPaise = toPaise(totalAmount) - toPaise(paidAmount);
    return remainingPaise <= 0 ? 0.0 : remainingPaise / 100.0;
  }

  static double? resolveDetectedReceiptAmount({
    required double detectedAmount,
    required double remainingDue,
    required bool isIncomingCredit,
    required bool isMerchantConfirmed,
    required bool isFailed,
    required bool isDuplicate,
    bool hasReferenceConflict = false,
  }) {
    // Detection alerts are candidates only; require explicit merchant
    // confirmation before changing sale accounting.
    if (!isIncomingCredit ||
        !isMerchantConfirmed ||
        isFailed ||
        isDuplicate ||
        hasReferenceConflict ||
        !detectedAmount.isFinite ||
        detectedAmount <= 0 ||
        !remainingDue.isFinite ||
        remainingDue <= 0) {
      return null;
    }
    return math.min(detectedAmount, remainingDue).toDouble();
  }

  static double resolvePaidAmount({
    required double totalAmount,
    required double enteredPaidAmount,
    required bool isBorrow,
    required bool isCashPayment,
    required bool paymentConfirmed,
  }) {
    if (!totalAmount.isFinite || totalAmount <= 0) return 0.0;
    final total = double.parse(totalAmount.toStringAsFixed(2));
    if (isBorrow) return 0.0;

    // The POS requires confirmation before submitting an online payment. Never
    // fabricate a receipt if that confirmation is missing.
    if (!isCashPayment && !paymentConfirmed) return 0.0;

    final entered = enteredPaidAmount.isFinite
        ? enteredPaidAmount.clamp(0.0, total).toDouble()
        : 0.0;
    if (entered > 0) return entered;

    // In cash mode, zero means no separate partial receipt was entered: the
    // ordinary checkout represents a completed, fully paid sale.
    // A confirmed online checkout with no amount recorded is likewise full.
    return total;
  }
}
