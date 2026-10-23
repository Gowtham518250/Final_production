/// Resolves a usable account email from legacy/current session key aliases.
class DailySummaryRecipient {
  static final RegExp _basicEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+);

  /// Returns the first non-empty email-like value, normalized for sending.
  /// Empty or malformed earlier keys must not mask a valid later fallback.
  static String resolve(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final email = (candidate ?? '').trim().toLowerCase();
      if (email.isNotEmpty && _basicEmailPattern.hasMatch(email)) {
        return email;
      }
    }
    return '';
  }
}
);

  /// Returns the first non-empty email-like value, normalized for sending.
  /// Empty or malformed earlier keys must not mask a valid later fallback.
  static String resolve(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final email = (candidate ?? '').trim().toLowerCase();
      if (email.isNotEmpty && _basicEmailPattern.hasMatch(email)) {
        return email;
      }
    }
    return '';
  }
}
