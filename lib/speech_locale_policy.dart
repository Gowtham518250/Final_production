/// Matches the requested speech locale against locales exposed by the device's
/// speech-recognition engine. Some engines expose `te_IN` while Flutter asks
/// for `te-IN`, so underscore/hyphen and region differences are normalized.
class SpeechLocalePolicy {
  SpeechLocalePolicy._();

  static bool isAvailable(
    String requestedLocale,
    Iterable<String> availableLocales,
  ) {
    final requested = normalize(requestedLocale);
    if (requested.isEmpty) return false;

    final requestedLanguage = requested.split('-').first;
    return availableLocales.any((rawLocale) {
      final available = normalize(rawLocale);
      if (available.isEmpty) return false;
      return available == requested ||
          available.split('-').first == requestedLanguage;
    });
  }

  /// Convert the app's saved language code (for example `te`) into the
  /// explicit locale passed to cloud transcription and on-device STT.
  /// Never send `auto` when a user has already chosen a language.
  static String toSpeechLocaleCode(String languageCode) {
    final normalized = normalize(languageCode);
    final base = normalized.split('-').first;
    const defaultLocales = <String, String>{
      'en': 'en-IN',
      'hi': 'hi-IN',
      'te': 'te-IN',
      'ta': 'ta-IN',
      'kn': 'kn-IN',
      'ml': 'ml-IN',
      'mr': 'mr-IN',
      'bn': 'bn-IN',
      'gu': 'gu-IN',
      'pa': 'pa-IN',
    };
    return defaultLocales[base] ?? 'te-IN';
  }

  static String normalize(String locale) =>
      locale.trim().replaceAll('_', '-').toLowerCase();
}
