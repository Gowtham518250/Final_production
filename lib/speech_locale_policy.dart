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

  static String normalize(String locale) =>
      locale.trim().replaceAll('_', '-').toLowerCase();
}
