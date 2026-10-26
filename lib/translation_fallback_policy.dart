/// Decisions for retrying dynamic display translations through the authenticated
/// backend when the on-device English-to-Indic translator cannot produce a
/// meaningful translation.
class TranslationFallbackPolicy {
  TranslationFallbackPolicy._();

  static bool needsRemoteFallback(String source, String translated) {
    final original = _normalizeForComparison(source);
    final candidate = _normalizeForComparison(translated);
    return original.isNotEmpty && (candidate.isEmpty || candidate == original);
  }

  static String _normalizeForComparison(String value) =>
      value.trim().replaceAll(RegExp(r'\\s+'), ' ').toLowerCase();
}
