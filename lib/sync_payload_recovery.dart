/// Rebuilds a legacy queued sale from its locally persisted financial record.
///
/// This is only a recovery path for older queue entries that contain a stable
/// sale/invoice ID but no embedded invoice payload. It never invents a date,
/// amount, quantity, or product name; ambiguous records stay queued for review.
///
/// The caller must pass the current user's locally scoped sales (the standard
/// sync path uses LocalStorageService.loadSales). When owner/shop identifiers
/// are present in both records, this helper also enforces that they agree.
Map<String, dynamic>? buildInvoicePayloadFromLocalSale(
  Map<String, dynamic> queueData,
  List<dynamic> localSales,
) {
  String textValue(dynamic value) => value?.toString().trim() ?? '';
  String normalized(dynamic value) => textValue(value).toLowerCase();
  String firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = textValue(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  bool provided(dynamic value) => textValue(value).isNotEmpty;

  double? numberValue(dynamic value) {
    if (value is num) {
      final result = value.toDouble();
      return result.isFinite ? result : null;
    }
    final result = double.tryParse(textValue(value));
    return result != null && result.isFinite ? result : null;
  }

  // Do not compare generic "id" fields: a queue operation ID, database row ID,
  // offline sale ID, and invoice number can belong to different namespaces.
  final queueSaleId = normalized(queueData['sale_id']);
  final queueOfflineId = normalized(queueData['offline_id']);
  final queueInvoiceNumber = normalized(queueData['invoice_number']);
  if (queueSaleId.isEmpty &&
      queueOfflineId.isEmpty &&
      queueInvoiceNumber.isEmpty) {
    return null;
  }

  bool ownershipConflicts(Map<String, dynamic> record) {
    for (final field in const [
      'user_id',
      'owner_id',
      'shop_id',
      'shopkeeper_id',
      'branch_id',
      'store_id',
    ]) {
      final queuedOwner = normalized(queueData[field]);
      final localOwner = normalized(record[field]);
      if (queuedOwner.isNotEmpty &&
          localOwner.isNotEmpty &&
          queuedOwner != localOwner) {
        return true;
      }
    }
    return false;
  }

  bool isCancelledOrVoided(Map<String, dynamic> record) {
    const blockedStatuses = {
      'CANCELLED',
      'CANCELED',
      'VOID',
      'VOIDED',
      'DELETED',
      'REFUNDED',
      'REVERSED',
    };
    for (final field in const [
      'status',
      'sale_status',
      'invoice_status',
      'sale_state',
    ]) {
      if (blockedStatuses.contains(textValue(record[field]).toUpperCase())) {
        return true;
      }
    }
    return record['is_cancelled'] == true ||
        record['is_canceled'] == true ||
        record['is_void'] == true ||
        record['is_voided'] == true ||
        provided(record['cancelled_at']) ||
        provided(record['canceled_at']) ||
        provided(record['voided_at']);
  }

  Map<String, dynamic>? localSale;
  for (final raw in localSales) {
    if (raw is! Map) continue;
    final record = Map<String, dynamic>.from(raw);
    final localSaleId = normalized(record['sale_id']);
    final localOfflineId = normalized(record['offline_id']);
    final localInvoiceIds = <String>{
      for (final value in [
        record['invoice_number'],
        record['bill_number'],
        record['invoice_display_number'],
      ])
        if (normalized(value).isNotEmpty) normalized(value),
    };

    final hasAuthoritativeMatch =
        (queueSaleId.isNotEmpty && queueSaleId == localSaleId) ||
        (queueOfflineId.isNotEmpty && queueOfflineId == localOfflineId) ||
        (queueInvoiceNumber.isNotEmpty &&
            localInvoiceIds.contains(queueInvoiceNumber));
    if (!hasAuthoritativeMatch) continue;

    // If any corresponding authoritative IDs disagree, the match is ambiguous
    // even when another alias happens to match. Keep it queued for manual review.
    final conflicts =
        (queueSaleId.isNotEmpty &&
            localSaleId.isNotEmpty &&
            queueSaleId != localSaleId) ||
        (queueOfflineId.isNotEmpty &&
            localOfflineId.isNotEmpty &&
            queueOfflineId != localOfflineId) ||
        (queueInvoiceNumber.isNotEmpty &&
            localInvoiceIds.isNotEmpty &&
            !localInvoiceIds.contains(queueInvoiceNumber));
    if (conflicts || ownershipConflicts(record)) continue;

    localSale = record;
    break;
  }
  if (localSale == null || isCancelledOrVoided(localSale)) return null;

  final rawItems = localSale['line_items'] ?? localSale['items'];
  if (rawItems is! List || rawItems.isEmpty) return null;

  final lineItems = <Map<String, dynamic>>[];
  double sumOfLines = 0;
  for (final rawItem in rawItems) {
    if (rawItem is! Map) return null;
    final item = Map<String, dynamic>.from(rawItem);
    final name = firstText([
      item['product_name'],
      item['description'],
      item['product'],
      item['item'],
      item['name'],
      item['title'],
    ]);
    final quantity = numberValue(item['quantity'] ?? item['qty']);
    final unitPrice = numberValue(item['unit_price'] ?? item['price']);
    final rawLineTotal =
        item['line_total'] ?? item['total_with_tax'] ?? item['total'];
    final lineTotalIsProvided = provided(rawLineTotal);
    final parsedLineTotal = lineTotalIsProvided
        ? numberValue(rawLineTotal)
        : null;

    final rawDiscount = item['discount_amount'];
    final discountAmount = provided(rawDiscount)
        ? numberValue(rawDiscount)
        : 0.0;
    if (name.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        unitPrice == null ||
        unitPrice < 0 ||
        (lineTotalIsProvided && parsedLineTotal == null) ||
        discountAmount == null ||
        discountAmount < 0) {
      return null;
    }

    final lineTotal = lineTotalIsProvided
        ? parsedLineTotal!
        : quantity * unitPrice;
    if (!lineTotal.isFinite || lineTotal < 0) return null;
    sumOfLines += lineTotal;

    final productId = int.tryParse(
      textValue(item['product_id'] ?? item['id']),
    );
    lineItems.add(<String, dynamic>{
      'product_id': productId != null && productId > 0 ? productId : null,
      'product_name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
      'discount_amount': discountAmount,
      if (textValue(item['discount_reason']).isNotEmpty)
        'discount_reason': textValue(item['discount_reason']),
      if (textValue(item['discount_source']).isNotEmpty)
        'discount_source': textValue(item['discount_source']),
    });
  }

  final invoiceNumber = firstText([
    queueData['invoice_number'],
    localSale['invoice_number'],
    localSale['bill_number'],
    localSale['invoice_display_number'],
    queueData['sale_id'],
    localSale['sale_id'],
  ]);
  final offlineId = firstText([
    queueData['offline_id'],
    localSale['offline_id'],
    localSale['sale_id'],
    invoiceNumber,
  ]);
  if (invoiceNumber.isEmpty || offlineId.isEmpty) return null;

  // Prefer a stored business date. Never silently use today's date for an
  // older queued sale because that would corrupt daily/monthly sales reports.
  final dateRaw = firstText([
    localSale['business_date'],
    localSale['invoice_date'],
    localSale['sale_date'],
    localSale['date'],
    queueData['invoice_date'],
    localSale['sale_timestamp'],
    localSale['created_at'],
    queueData['sale_timestamp'],
  ]);
  final parsedDate = DateTime.tryParse(dateRaw);
  if (parsedDate == null) return null;
  final invoiceDate = parsedDate.toIso8601String().substring(0, 10);

  final rawTotal = firstText([
    queueData['total_amount'],
    queueData['total'],
    localSale['total_amount'],
    localSale['grand_total'],
    localSale['total'],
  ]);
  final totalAmount = rawTotal.isEmpty ? sumOfLines : numberValue(rawTotal);
  final rawPaidAmount = firstText([
    queueData['paid_amount'],
    queueData['amount_paid'],
    localSale['paid_amount'],
    localSale['amount_paid'],
  ]);
  final paidAmount = rawPaidAmount.isEmpty ? 0.0 : numberValue(rawPaidAmount);
  final rawTax = firstText([queueData['tax'], localSale['tax']]);
  final tax = rawTax.isEmpty ? 0.0 : numberValue(rawTax);
  if (totalAmount == null ||
      !totalAmount.isFinite ||
      totalAmount < 0 ||
      paidAmount == null ||
      !paidAmount.isFinite ||
      paidAmount < 0 ||
      paidAmount > totalAmount + 0.01 ||
      tax == null ||
      !tax.isFinite ||
      tax < 0 ||
      !sumOfLines.isFinite) {
    return null;
  }

  final paymentStatus = paidAmount >= totalAmount - 0.01
      ? 'PAID'
      : paidAmount > 0.01
      ? 'PARTIAL'
      : 'UNPAID';

  final customerName = firstText([
    queueData['customer_name'],
    localSale['customer_name'],
  ]);
  final customerPhone = firstText([
    queueData['customer_phone'],
    localSale['customer_phone'],
  ]);
  final paymentMethod = firstText([
    queueData['payment_method'],
    localSale['payment_method'],
  ]);
  final notes = firstText([queueData['notes'], localSale['notes']]);

  // Never fabricate midnight UTC when the actual transaction timestamp is
  // unavailable. The business date is sufficient for daily reporting; the
  // exact timestamp remains absent rather than pretending it is known.
  final timestamp = firstText([
    queueData['sale_timestamp'],
    queueData['created_at'],
    localSale['sale_timestamp'],
    localSale['created_at'],
  ]);
  if (timestamp.isNotEmpty && DateTime.tryParse(timestamp) == null) return null;

  return <String, dynamic>{
    'invoice_number': invoiceNumber,
    'offline_id': offlineId,
    'customer_name': customerName.isNotEmpty ? customerName : 'Cash Customer',
    if (customerPhone.isNotEmpty) 'customer_phone': customerPhone,
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'tax': tax,
    'payment_status': paymentStatus,
    if (paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
    'invoice_date': invoiceDate,
    if (timestamp.isNotEmpty) 'sale_timestamp': timestamp,
    if (notes.isNotEmpty) 'notes': notes,
    'line_items': lineItems,
  };
}
