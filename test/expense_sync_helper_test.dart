import 'package:flutter_test/flutter_test.dart';

import 'package:retail_mind/expense_sync_helper.dart';

void main() {
  group('ExpenseSyncHelper', () {
    test(
      'selects due unconfirmed expenses but skips synced and deferred rows',
      () {
        final now = DateTime.utc(2026, 11, 6, 10);
        final pending = ExpenseSyncHelper.pendingExpenses(<dynamic>[
          <String, dynamic>{
            'id': 'due',
            'sync_status': 'pending_confirmation',
            'is_synced': false,
          },
          <String, dynamic>{
            'id': 'synced',
            'sync_status': 'pending_confirmation',
            'is_synced': true,
          },
          <String, dynamic>{
            'id': 'backoff',
            'sync_status': 'pending_confirmation',
            'retry_after': now
                .add(const Duration(minutes: 1))
                .toIso8601String(),
          },
          <String, dynamic>{'id': 'ordinary'},
        ], now: now);

        expect(pending.map((row) => row['id']), <String>['due']);
      },
    );

    test(
      'retries reuse the stable operation id as the server idempotency key',
      () {
        expect(
          ExpenseSyncHelper.idempotencyKey(<String, dynamic>{
            'operation_id': 'expense_123456789',
            'local_id': 'different-local-id',
          }),
          'expense_123456789',
        );
        expect(
          ExpenseSyncHelper.idempotencyKey(<String, dynamic>{
            'local_id': '123456789',
          }),
          'expense_123456789',
        );
        expect(ExpenseSyncHelper.idempotencyKey(<String, dynamic>{}), isNull);
      },
    );

    test('retry backoff increases and is capped at one hour', () {
      final now = DateTime.utc(2026, 11, 6, 10);

      expect(
        ExpenseSyncHelper.nextRetryAt(1, now: now),
        now.add(const Duration(minutes: 1)),
      );
      expect(
        ExpenseSyncHelper.nextRetryAt(4, now: now),
        now.add(const Duration(minutes: 8)),
      );
      expect(
        ExpenseSyncHelper.nextRetryAt(20, now: now),
        now.add(const Duration(minutes: 60)),
      );
    });
  });
}
