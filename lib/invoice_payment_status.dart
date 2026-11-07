import 'payment_idempotency_ledger.dart';

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

Map<String, dynamic> mergeInvoicePaymentState(
  Map<String, dynamic> current,
  Map<String, dynamic> incoming,
) {
  final merged = Map<String, dynamic>.from(current);

  double amountFrom(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed.isFinite && parsed > 0) return parsed;
    }
    return 0;
  }

  double highestAmount(Map<String, dynamic> row, List<String> keys) {
    var highest = 0.0;
    for (final key in keys) {
      final value = row[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed.isFinite && parsed > highest) {
        highest = parsed;
      }
    }
    return highest;
  }

  const paidKeys = ['paid_amount', 'amount_paid', 'paid', 'received_amount'];
  final incomingStatus = (incoming['payment_status'] ?? incoming['status'])
      ?.toString()
      .trim();
  final normalizedIncomingStatus =
      incomingStatus?.split('.').last.toUpperCase() ?? '';
  const paymentStatuses = {
    'PAID',
    'COMPLETED',
    'SETTLED',
    'PARTIAL',
    'PARTIALLY_PAID',
    'UNPAID',
    'PENDING',
    'DUE',
    'OVERDUE',
  };
  final hasIncomingPaymentStatus = paymentStatuses.contains(
    normalizedIncomingStatus,
  );
  final hasIncomingPaidAmount = paidKeys.any((key) => incoming[key] != null);
  if (!hasIncomingPaymentStatus && !hasIncomingPaidAmount) {
    return merged;
  }

  final currentTotal = amountFrom(current, const [
    'total_amount',
    'total',
    'invoice_total',
    'grand_total',
  ]);
  final incomingTotal = amountFrom(incoming, const [
    'total_amount',
    'total',
    'invoice_total',
    'grand_total',
  ]);
  final total = incomingTotal > 0 ? incomingTotal : currentTotal;
  final currentPaid = highestAmount(current, paidKeys);
  final incomingPaid = highestAmount(incoming, paidKeys);
  var paid = currentPaid > incomingPaid ? currentPaid : incomingPaid;
  final currentStatus = (current['payment_status'] ?? current['status'] ?? '')
      .toString()
      .split('.')
      .last
      .toUpperCase();
  if (total > 0 &&
      paid <= 0 &&
      const {'PAID', 'COMPLETED', 'SETTLED'}.contains(currentStatus)) {
    paid = total;
  }

  if (total > 0 &&
      const {
        'PAID',
        'COMPLETED',
        'SETTLED',
      }.contains(normalizedIncomingStatus)) {
    paid = total;
  }

  final String status;
  if (total > 0 && paid > 0) {
    status = invoicePaymentStatusFor(total, paid);
  } else if (currentStatus == 'PARTIAL' &&
      normalizedIncomingStatus == 'UNPAID') {
    status = currentStatus;
  } else if (hasIncomingPaymentStatus) {
    status = normalizedIncomingStatus;
  } else {
    status = currentStatus;
  }

  merged
    ..['paid_amount'] = paid
    ..['amount_paid'] = paid
    ..['payment_status'] = status
    ..['status'] = status;
  if (total > 0) {
    merged['pending_amount'] = (total - paid)
        .clamp(0.0, double.infinity)
        .toDouble();
  }
  return merged;
}

/// Applies a payment event once, even when the same detected event is replayed.
///
/// Returns null when the event is invalid or its idempotency key was already
/// applied to this invoice.
Map<String, dynamic>? applyInvoicePaymentOnce(
  Map<String, dynamic> invoice, {
  required double amount,
  required String idempotencyKey,
}) {
  if (!amount.isFinite || amount <= 0 || idempotencyKey.trim().isEmpty) {
    return null;
  }
  if (PaymentIdempotencyLedger.contains(invoice, idempotencyKey)) return null;

  double readAmount(List<String> keys) {
    var result = 0.0;
    for (final key in keys) {
      final value = invoice[key];
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed.isFinite && parsed > result) {
        result = parsed;
      }
    }
    return result;
  }

  final total = readAmount([
    'total_amount',
    'total',
    'invoice_total',
    'grand_total',
  ]);
  if (total <= 0) return null;

  final oldPaid = readAmount([
    'paid_amount',
    'amount_paid',
    'paid',
    'received_amount',
  ]);
  final paid = (oldPaid + amount).clamp(0.0, total).toDouble();
  final status = invoicePaymentStatusFor(total, paid);
  final updated = Map<String, dynamic>.from(invoice)
    ..['paid_amount'] = paid
    ..['amount_paid'] = paid
    ..['payment_status'] = status
    ..['status'] = status
    ..['pending_amount'] = (total - paid).clamp(0.0, double.infinity).toDouble()
    ..['last_payment_amount'] = amount;
  PaymentIdempotencyLedger.remember(updated, idempotencyKey);
  return updated;
}

/// Finds an invoice only when a payment event carries an exact invoice alias.
/// A payer name or the fact that there is only one open invoice is not enough
/// evidence to assign an incoming payment automatically.
Map<String, dynamic>? findInvoiceByExplicitPaymentReference(
  List<Map<String, dynamic>> invoices,
  String? reference,
) {
  final normalizedReference = reference?.trim().toLowerCase() ?? '';
  if (normalizedReference.isEmpty || normalizedReference == 'null') {
    return null;
  }

  const identityFields = [
    'invoice_id',
    'sale_id',
    'invoice_number',
    'invoiceId',
    'backend_id',
    'id',
  ];
  final matches = invoices.where((invoice) {
    return identityFields.any(
      (field) =>
          invoice[field]?.toString().trim().toLowerCase() ==
          normalizedReference,
    );
  }).toList();
  return matches.length == 1 ? matches.single : null;
}

/// Rupee amounts compared as integer paise so a ₹1 gap cannot settle a bill.
int rupeesToPaise(double rupees) {
  if (!rupees.isFinite) return 0;
  return (rupees * 100).round();
}

double invoiceRecordTotal(Map<String, dynamic> row) {
  return _highestAmount(row, const [
    'total_amount',
    'total',
    'invoice_total',
    'grand_total',
  ]);
}

double invoiceRecordPaid(Map<String, dynamic> row) {
  return _highestAmount(row, const [
    'paid_amount',
    'amount_paid',
    'paid',
    'received_amount',
  ]);
}

double _highestAmount(Map<String, dynamic> row, List<String> keys) {
  var highest = 0.0;
  for (final key in keys) {
    final value = row[key];
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed.isFinite && parsed > highest) {
      highest = parsed;
    }
  }
  return highest;
}

bool paymentFitsOpenBalance(Map<String, dynamic> row, double amount) {
  final total = invoiceRecordTotal(row);
  final paid = invoiceRecordPaid(row);
  final duePaise = rupeesToPaise(
    (total - paid).clamp(0.0, double.infinity).toDouble(),
  );
  final amountPaise = rupeesToPaise(amount);
  return total > 0 && duePaise > 0 && amountPaise > 0 && amountPaise <= duePaise;
}

String? canonicalInvoiceNumber(Map<String, dynamic> row) {
  for (final key in const [
    'invoice_number',
    'sale_id',
    'invoice_id',
    'invoiceId',
    'backend_id',
    'id',
  ]) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != '0' && value.toLowerCase() != 'null') {
      return value;
    }
  }
  return null;
}

class AutoSettleTarget {
  const AutoSettleTarget({
    this.saleIndex,
    this.invoiceIndex,
    required this.invoiceNumber,
  });

  final int? saleIndex;
  final int? invoiceIndex;
  final String invoiceNumber;
}

/// Auto-settlement is allowed only for one explicit invoice/sale reference.
/// Matching due amounts without that reference stay pending for the owner.
AutoSettleTarget? selectUnambiguousAutoSettleTarget({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> invoices,
  required String? reference,
  required double amount,
}) {
  if (!amount.isFinite || amount <= 0) return null;

  final sale = findInvoiceByExplicitPaymentReference(sales, reference);
  final invoice = findInvoiceByExplicitPaymentReference(invoices, reference);
  if (sale == null && invoice == null) return null;
  if (sale != null && !paymentFitsOpenBalance(sale, amount)) return null;
  if (invoice != null && !paymentFitsOpenBalance(invoice, amount)) return null;

  final saleNumber = sale == null ? null : canonicalInvoiceNumber(sale);
  final invoiceNumber = invoice == null ? null : canonicalInvoiceNumber(invoice);
  if (sale != null && (saleNumber == null || saleNumber.isEmpty)) return null;
  if (invoice != null && (invoiceNumber == null || invoiceNumber.isEmpty)) {
    return null;
  }
  if (saleNumber != null &&
      invoiceNumber != null &&
      saleNumber.toLowerCase() != invoiceNumber.toLowerCase()) {
    return null;
  }

  return AutoSettleTarget(
    saleIndex: sale == null ? null : sales.indexOf(sale),
    invoiceIndex: invoice == null ? null : invoices.indexOf(invoice),
    invoiceNumber: saleNumber ?? invoiceNumber!,
  );
}
