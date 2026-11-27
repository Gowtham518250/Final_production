import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;
import 'local_storage_service.dart';
import 'payment_event.dart';

/// Offline Payment Queue - Handles pending payments when offline
class OfflinePaymentQueue {
  static const String _tag = '📋 OFFLINE_QUEUE';
  static const String _queueKey = 'offline_payments_queue_v1';
  static const String _syncStatusKey = 'offline_sync_status';
  
  final LocalStorageService _storage = LocalStorageService();
  
  // Shared across instances: multiple screens/services can enqueue the same event.
  // An instance-local lock allowed concurrent writers to overwrite each other's queue.
  static Future<void> _writeLock = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final completer = Completer<void>();
    final previous = _writeLock;
    _writeLock = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }
  
  /// Queue a payment when offline
  Future<void> queuePaymentOffline(PaymentEvent payment) {
    return _synchronized(() async {
      try {
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final decoded = jsonDecode(queueJson);
        if (decoded is! List) {
          throw const FormatException('Offline payment queue must be a JSON list.');
        }
        final List<dynamic> queue = decoded;
        if (!payment.amount.isFinite || payment.amount <= 0 ||
            payment.isFailed || payment.isDuplicate || payment.hasReferenceConflict) {
          throw const FormatException('Only valid, non-duplicate payment events can be queued.');
        }
        final idempotencyKey = payment.fingerprint.trim();
        final alreadyQueued = queue.whereType<Map>().any((entry) {
          final oldId = (entry['id'] ?? '').toString();
          final oldKey = (entry['idempotency_key'] ?? '').toString();
          return oldId == payment.id ||
              (idempotencyKey.isNotEmpty && oldKey == idempotencyKey);
        });
        if (alreadyQueued) {
          if (foundation.kDebugMode) {
            print('$_tag ↩️ Duplicate payment ignored: ${payment.id}');
          }
          return;
        }
        final paymentData = {
          'id': payment.id,
          'invoice_number': payment.saleId,
          'amount': payment.amount,
          'app': payment.app.toString(),
          'payerName': payment.payerName,
          'referenceId': payment.referenceId,
          'reference_id': payment.referenceId,
          'idempotency_key': idempotencyKey.isEmpty ? payment.id : idempotencyKey,
          'source_event_key': payment.sourceEventKey,
          'direction': payment.direction.name,
          'payment_method': 'ONLINE',
          'source': payment.detectionSource,
          'payer_name': payment.payerName,
          'vpa': payment.vpa,
          'bankName': payment.bankName,
          'isFailed': payment.isFailed,
          'isDuplicate': payment.isDuplicate,
          'isPartialPayment': payment.isPartialPayment,
          'confidenceScore': payment.confidenceScore,
          'detectionSource': payment.detectionSource,
          'rawText': payment.rawText,
          'decision': payment.decision.toString(),
          'timestamp': payment.timestamp.toIso8601String(),
          'queuedAt': DateTime.now().toIso8601String(),
          'retryCount': 0,
          'status': 'PENDING',
        };
        
        queue.add(paymentData);
        await _storage.setString(_queueKey, jsonEncode(queue));
        
        if (foundation.kDebugMode) {
          print('$_tag ✅ Payment queued offline: ₹${payment.amount} | Total: ${queue.length}');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to queue: $e');
      }
    });
  }
  
  /// Get all queued payments
  Future<List<Map<String, dynamic>>> getQueuedPayments() async {
    try {
      final queueJson = await _storage.getString(_queueKey) ?? '[]';
      final decoded = jsonDecode(queueJson);
      if (decoded is! List) throw const FormatException('Offline payment queue must be a JSON list.');
      return decoded.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
    } catch (e) {
      if (foundation.kDebugMode) print('$_tag ❌ Failed to get queue: $e');
      return [];
    }
  }
  
  /// Get count of pending payments
  Future<int> getPendingCount() async {
    final queue = await getQueuedPayments();
    return queue.where((p) => p['status'] == 'PENDING').length;
  }
  
  /// Mark payment as synced
  Future<void> markAsSynced(String paymentId) {
    return _synchronized(() async {
      try {
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final index = queue.indexWhere((p) => p['id'] == paymentId);
        if (index != -1) {
          queue[index]['status'] = 'SYNCED';
          queue[index]['syncedAt'] = DateTime.now().toIso8601String();
          await _storage.setString(_queueKey, jsonEncode(queue));
          
          if (foundation.kDebugMode) print('$_tag ✅ Payment marked synced: $paymentId');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to mark synced: $e');
      }
    });
  }
  
  /// Mark payment as failed (max retries exceeded)
  Future<void> markAsFailed(String paymentId) {
    return _synchronized(() async {
      try {
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final index = queue.indexWhere((p) => p['id'] == paymentId);
        if (index != -1) {
          queue[index]['status'] = 'FAILED';
          queue[index]['failedAt'] = DateTime.now().toIso8601String();
          await _storage.setString(_queueKey, jsonEncode(queue));
          
          if (foundation.kDebugMode) print('$_tag ⚠️ Payment marked failed: $paymentId');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to mark as failed: $e');
      }
    });
  }
  
  /// Increment retry count
  Future<bool> incrementRetryCount(String paymentId) {
    return _synchronized(() async {
      try {
        const maxRetries = 5;
        final queueJson = await _storage.getString(_queueKey) ?? '[]';
        final List<dynamic> queue = jsonDecode(queueJson);
        
        final index = queue.indexWhere((p) => p['id'] == paymentId);
        if (index != -1) {
          final currentRetries = (queue[index]['retryCount'] as num?)?.toInt() ?? 0;
          final nextRetries = currentRetries + 1;
          queue[index]['retryCount'] = nextRetries;
          
          if (nextRetries >= maxRetries) {
            queue[index]['status'] = 'FAILED';
            queue[index]['failedAt'] = DateTime.now().toIso8601String();
            await _storage.setString(_queueKey, jsonEncode(queue));
            if (foundation.kDebugMode) print('$_tag ⚠️ Payment marked failed: $paymentId');
            return false;
          }
          
          await _storage.setString(_queueKey, jsonEncode(queue));
          return true;
        }
        return false;
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to increment retry: $e');
        return false;
      }
    });
  }
  
  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final statusJson = await _storage.getString(_syncStatusKey) ?? 
          jsonEncode({
            'lastSyncAt': null,
            'totalSynced': 0,
            'totalFailed': 0,
          });
      return jsonDecode(statusJson);
    } catch (e) {
      return {
        'lastSyncAt': null,
        'totalSynced': 0,
        'totalFailed': 0,
      };
    }
  }
  
  /// Update sync status
  Future<void> updateSyncStatus({
    int? synced,
    int? failed,
  }) {
    return _synchronized(() async {
      try {
        final raw = await _storage.getString(_syncStatusKey);
        final decoded = raw == null ? null : jsonDecode(raw);
        final status = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{
                'lastSyncAt': null,
                'totalSynced': 0,
                'totalFailed': 0,
              };
        if (synced != null) {
          final current = (status['totalSynced'] as num?)?.toInt() ?? 0;
          status['totalSynced'] = current + synced;
        }
        if (failed != null) {
          final current = (status['totalFailed'] as num?)?.toInt() ?? 0;
          status['totalFailed'] = current + failed;
        }
        status['lastSyncAt'] = DateTime.now().toIso8601String();
        await _storage.setString(_syncStatusKey, jsonEncode(status));
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to update status: $e');
      }
    });
  }
  
  /// FIX-5: Clear queue with audit trail — preserves failed payments for investigation
  /// Use preserveFailed=false only after manual audit/remediation
  Future<void> clearQueue({bool preserveFailed = true}) {
    return _synchronized(() async {
      try {
        if (preserveFailed) {
          final queueJson = await _storage.getString(_queueKey) ?? '[]';
          final List<dynamic> queue = jsonDecode(queueJson);
          // Keep FAILED payments for audit trail
          final failed = queue.where((p) => p['status'] == 'FAILED').toList();
          await _storage.setString(_queueKey, jsonEncode(failed));
          if (foundation.kDebugMode) print('$_tag ✅ Queue cleared. Preserved ${failed.length} failed payments for audit.');
        } else {
          await _storage.setString(_queueKey, '[]');
          if (foundation.kDebugMode) print('$_tag ✅ Queue cleared completely');
        }
      } catch (e) {
        if (foundation.kDebugMode) print('$_tag ❌ Failed to clear: $e');
      }
    });
  }
}
