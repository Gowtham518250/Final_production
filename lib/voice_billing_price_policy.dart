/// Price handling shared by voice-billing parsing and the final billing gate.
///
/// A price identified as spoken must remain a proposal for cashier review.
/// Catalogue prices are only the default when the parser explicitly reports
/// that the selected price came from the catalogue.
class VoiceBillingPricePolicy {
  static const Set<String> _spokenSources = <String>{
    'spoken',
    'spoken_unit',
    'spoken_line_total',
  };

  static String _normalizeSource(String? source) =>
      (source ?? '').trim().toLowerCase();

  static bool isSpokenSource(String? source) =>
      _spokenSources.contains(_normalizeSource(source));

  static double? positivePrice(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse((value ?? '').toString().trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  static VoiceBillingPriceResolution resolveParsedPrice({
    required String? rawPriceSource,
    required double? detectedPrice,
    required double? cataloguePrice,
    required String productName,
  }) {
    final source = _normalizeSource(rawPriceSource);
    final spoken = isSpokenSource(source) ? positivePrice(detectedPrice) : null;
    final catalogue = positivePrice(cataloguePrice);

    if (spoken != null) {
      String? warning;
      if (catalogue == null) {
        warning =
            'No valid selling price is saved for $productName. The spoken '
            'price ₹${spoken.toStringAsFixed(2)} is shown for review; '
            'confirm or edit it before billing.';
      } else if ((spoken - catalogue).abs() >= 0.01) {
        warning =
            'The spoken price for $productName was recognized as '
            '₹${spoken.toStringAsFixed(2)}, while this shop lists '
            '₹${catalogue.toStringAsFixed(2)}. The spoken price is shown '
            'for review; confirm or edit it before billing.';
      }
      return VoiceBillingPriceResolution(
        price: spoken,
        source: source,
        warning: warning,
      );
    }

    if (catalogue != null) {
      return VoiceBillingPriceResolution(price: catalogue, source: 'catalog');
    }

    return const VoiceBillingPriceResolution(price: null, source: 'missing');
  }

  /// Re-apply the same pricing rule before a reviewed item reaches a bill.
  /// A valid spoken price is preserved; catalogue price is only the fallback
  /// for catalogue-sourced (or missing) proposals. Manual edits always win.
  static double resolveFinalPrice({
    required String? priceSource,
    required double? itemPrice,
    required double? cataloguePrice,
  }) {
    final source = _normalizeSource(priceSource);
    if (source == 'manual') {
      return positivePrice(itemPrice) ?? 0.0;
    }
    if (isSpokenSource(source)) {
      return positivePrice(itemPrice) ?? positivePrice(cataloguePrice) ?? 0.0;
    }
    return positivePrice(cataloguePrice) ?? 0.0;
  }
}

class VoiceBillingPriceResolution {
  const VoiceBillingPriceResolution({
    required this.price,
    required this.source,
    this.warning,
  });

  final double? price;
  final String source;
  final String? warning;

  bool get hasPrice => price != null && price!.isFinite && price! > 0;
}
