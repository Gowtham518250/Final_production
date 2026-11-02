/// Shared safety policy for voice-billing responses from the backend.
///
/// A draft line must not be auto-added or confirmed when the server says its
/// catalogue match, unit, quantity, or price needs manual review.
bool voiceBillingItemNeedsManualReview(Map<dynamic, dynamic> item) {
  return item['needs_confirmation'] == true ||
      item['unit_mismatch'] == true ||
      item['quantity_grounded'] == false;
}

bool voiceBillingResponseNeedsManualReview(Map<String, dynamic> payload) {
  if (payload['needs_clarification'] == true ||
      payload['needs_confirmation'] == true) {
    return true;
  }

  final rawItems = payload['items'];
  if (rawItems is! List) return false;

  return rawItems.any(
    (value) => value is Map && voiceBillingItemNeedsManualReview(value),
  );
}

String voiceBillingManualReviewMessage(Map<String, dynamic> payload) {
  final clarification = (payload['clarification_question'] ?? '')
      .toString()
      .trim();
  if (clarification.isNotEmpty) {
    return 'No voice items were added because the result needs manual confirmation. $clarification';
  }
  return 'No voice items were added because a product, unit, quantity, or price could not be verified. Correct the item or enter it manually.';
}

/// Explains a skipped voice line without displaying model-generated IDs or
/// trusting candidate data as a product selection.
String voiceBillingItemReviewWarning(Map<dynamic, dynamic> item) {
  final name = (item['product_name_en'] ??
          item['product_name'] ??
          item['item'] ??
          'This item')
      .toString()
      .trim();
  final candidates = item['ambiguous_candidates'];
  final candidateNames = <String>[];
  if (candidates is List) {
    for (final candidate in candidates) {
      if (candidate is Map) {
        final candidateName = (candidate['name'] ?? '').toString().trim();
        if (candidateName.isNotEmpty && !candidateNames.contains(candidateName)) {
          candidateNames.add(candidateName);
        }
      }
    }
  }

  final details = <String>[];
  if (item['unit_mismatch'] == true) {
    details.add('the spoken unit does not match the saved selling unit');
  }
  if (item['quantity_grounded'] == false) {
    details.add('the quantity could not be verified against the speech');
  }
  if (candidateNames.isNotEmpty) {
    details.add('possible catalogue matches: ${candidateNames.take(3).join(', ')}');
  }
  if (item['price_missing'] == true) {
    details.add('the selling price is missing');
  }
  if (details.isEmpty) {
    details.add('manual confirmation is required');
  }
  return '$name was not added: ${details.join('; ')}. Select or enter the correct item manually.';
}
