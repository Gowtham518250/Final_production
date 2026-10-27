/// Helpers that avoid spending translation work on values that have no
/// human-language content.
class TranslationTextPolicy {
  TranslationTextPolicy._();

  static final RegExp _standaloneNumberOrCurrency = RegExp(
    r'^(?:[₹$€£¥]\\s*)?[+-]?\\d[\\d,]*(?:\\.\\d+)?\\s*(?:%|₹|INR|USD|EUR|GBP)?$',
    caseSensitive: false,
  );

  /// Returns true for values such as "500", "₹1,200.00", "14.5%" and "USD 20".
  /// It intentionally doesn't match descriptions such as "500 grams of rice".
  static bool isStandaloneNumberOrCurrency(String value) =>
      _standaloneNumberOrCurrency.hasMatch(value.trim());
}
