/// Shared safety rules for voice-billing line reconciliation and API fallback.
class VoiceBillingApiException implements Exception {
  const VoiceBillingApiException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  bool get isTransient =>
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      statusCode >= 500;

  @override
  String toString() => message;
}

class VoiceBillingSafetyPolicy {
  const VoiceBillingSafetyPolicy._();

  /// Model confidence must be a finite probability in [0, 1].
  static bool hasValidConfidence(double confidence) =>
      confidence.isFinite && confidence >= 0 && confidence <= 1;

  /// Keep backend ambiguity and grounding signals attached to the bill line.
  static bool requiresManualReview(Map<String, dynamic> item) {
    bool isTrue(Object? value) =>
        value == true || (value is String && value.trim().toLowerCase() == 'true');
    bool isFalse(Object? value) =>
        value == false || (value is String && value.trim().toLowerCase() == 'false');

    final candidates = item['ambiguous_candidates'];
    final hasCandidates = candidates is Map
        ? candidates.isNotEmpty
        : candidates is Iterable
            ? candidates.isNotEmpty
            : candidates is String && candidates.trim().isNotEmpty;

    return isTrue(item['needs_confirmation']) ||
        isTrue(item['unit_mismatch']) ||
        isFalse(item['quantity_grounded']) ||
        hasCandidates;
  }

  /// Merge only lines whose identity, unit, price and price provenance agree.
  /// A priced line must never lend its price to an unpriced quantity.
  static bool canMerge({
    required String currentName,
    required String currentUnit,
    required double currentPrice,
    required String currentPriceSource,
    required String incomingName,
    required String incomingUnit,
    required double incomingPrice,
    required String incomingPriceSource,
  }) {
    if (currentName.trim().toLowerCase() !=
            incomingName.trim().toLowerCase() ||
        currentUnit.trim().toLowerCase() !=
            incomingUnit.trim().toLowerCase()) {
      return false;
    }

    final currentHasPrice = currentPrice.isFinite && currentPrice > 0;
    final incomingHasPrice = incomingPrice.isFinite && incomingPrice > 0;
    if (currentHasPrice != incomingHasPrice) return false;

    final currentSource = currentPriceSource.trim().toLowerCase();
    final incomingSource = incomingPriceSource.trim().toLowerCase();
    if (currentSource != incomingSource) return false;

    if (!currentHasPrice) return true;
    return (currentPrice - incomingPrice).abs() < 0.01;
  }
}
