class ExpenseSyncHelper {
  static const Set<String> _pendingStatuses = <String>{
    'pending',
    'pending_confirmation',
    'pending_sync',
    'retry_wait',
    'failed',
  };

  static List<Map<String, dynamic>> pendingExpenses(
    List<dynamic> expenses, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return expenses.whereType<Map>().map(Map<String, dynamic>.from).where((
      expense,
    ) {
      if (expense['is_synced'] == true) return false;
      final status = expense['sync_status']?.toString().trim().toLowerCase();
      if (!_pendingStatuses.contains(status)) return false;
      final retryAfter = DateTime.tryParse(
        expense['retry_after']?.toString() ?? '',
      );
      return retryAfter == null || !retryAfter.isAfter(currentTime);
    }).toList();
  }

  static String? idempotencyKey(Map<String, dynamic> expense) {
    final operationId = expense['operation_id']?.toString().trim();
    final localId =
        expense['local_id']?.toString().trim() ??
        expense['id']?.toString().trim();
    final candidate = operationId != null && operationId.isNotEmpty
        ? operationId
        : localId == null || localId.isEmpty
        ? null
        : 'expense_$localId';
    if (candidate == null || candidate.length < 8 || candidate.length > 128) {
      return null;
    }
    return candidate;
  }

  static DateTime nextRetryAt(int attempt, {DateTime? now}) {
    final boundedAttempt = attempt.clamp(1, 10);
    final delayMinutes = 1 << (boundedAttempt - 1);
    return (now ?? DateTime.now()).add(
      Duration(minutes: delayMinutes > 60 ? 60 : delayMinutes),
    );
  }
}
