/// Durable representation helpers for payment idempotency keys.
///
/// Older records stored only `last_payment_idempotency_key`. New records keep
/// every applied key so a replay of an older payment cannot be applied again
/// after a later payment updates the row.
abstract final class PaymentIdempotencyLedger {
  static bool contains(Map<String, dynamic> record, String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) return false;

    final keys = record['payment_idempotency_keys'];
    if (keys is List && keys.any((value) => value?.toString() == normalized)) {
      return true;
    }

    // Read the legacy single-key field during migration.
    return record['last_payment_idempotency_key']?.toString() == normalized;
  }

  static void remember(Map<String, dynamic> record, String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) return;

    final stored = record['payment_idempotency_keys'];
    final keys = stored is List
        ? stored.map((value) => value.toString()).toSet()
        : <String>{};
    keys.add(normalized);
    record['payment_idempotency_keys'] = keys.toList(growable: false);
    // Retain this field for older app versions that only understand the last
    // key, while the list above remains the authoritative replay guard.
    record['last_payment_idempotency_key'] = normalized;
  }
}
