/// Canonical status derivation for invoice payment amounts.
///
/// A payment status must come from the amount actually recorded, not from a
/// stale display label. Zero or invalid totals cannot be marked PAID/PARTIAL.
String invoicePaymentStatusFor(double total, double paid) {
  if (!total.isFinite || total <= 0) return 'UNPAID';

  final normalizedTotal = double.parse(total.toStringAsFixed(2));
  final safePaid = paid.isFinite ? paid.clamp(0.0, normalizedTotal) : 0.0;
  final normalizedPaid = double.parse(safePaid.toStringAsFixed(2));

  // Only a positive recorded amount can settle an invoice, including very
  // small invoices where the one-paise settlement tolerance would otherwise
  // classify a zero payment as PAID.
  if (normalizedPaid > 0 && normalizedPaid >= normalizedTotal - 0.01) {
    return 'PAID';
  }
  if (normalizedPaid > 0) return 'PARTIAL';
  return 'UNPAID';
}
