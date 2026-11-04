import 'dart:math' as math;

/// Tracks confirmed and pending payments against the bill currently being sold.
/// Pending detections affect echo decisions and spoken balances, never accounting.
class BillContext {
  double? expectedAmount;
  bool isActive = false;
  DateTime? setAt;
  double _partialReceived = 0;

  static const Duration pendingTtl = Duration(minutes: 15);
  static const Duration settledEchoWindow = Duration(minutes: 12);
  static const Duration coveredBillEchoWindow = Duration(minutes: 12);

  final Map<String, _PendingPayment> _pending = <String, _PendingPayment>{};

  void setExpected(double amount) {
    assert(amount > 0);
    final isNewBill = !isActive || expectedAmount == null;
    if (isNewBill) {
      _partialReceived = 0;
      _pending.clear();
    }
    expectedAmount = amount;
    isActive = true;
    setAt = DateTime.now();
  }

  void clear() {
    expectedAmount = null;
    isActive = false;
    setAt = null;
    _partialReceived = 0;
    _pending.clear();
  }

  bool get isExpired => !isActive || expectedAmount == null;

  void recordPartial(double amount) => _partialReceived += amount;

  double get partialReceived => _partialReceived;

  double get remainingAmount => (expectedAmount ?? 0) - _partialReceived;

  bool get isFullyPaid =>
      expectedAmount != null && (partialReceived - expectedAmount!).abs() < 1.0;

  DateTime? _lastSettlementAt;

  bool get isSettlementLocked {
    if (_lastSettlementAt == null) return false;
    return DateTime.now().difference(_lastSettlementAt!) <
        const Duration(seconds: 5);
  }

  void markSettled() => _lastSettlementAt = DateTime.now();

  BillMatchResult evaluate(double detected) {
    if (!isActive || isExpired || expectedAmount == null) {
      return BillMatchResult.noContext;
    }
    final remaining = expectedAmount! - _partialReceived;
    if (remaining <= 0) return BillMatchResult.noContext;
    if (detected > expectedAmount! * 2.0) return BillMatchResult.suspicious;
    if (detected >= remaining) return BillMatchResult.exact;
    if (detected > 0) return BillMatchResult.partial;
    return BillMatchResult.mismatch;
  }

  void notePending(String id, double amount, {DateTime? at}) {
    if (!isActive || id.isEmpty || !amount.isFinite || amount <= 0) return;
    _pending[id] = _PendingPayment(amount, at ?? DateTime.now());
  }

  void releasePending(String id) => _pending.remove(id);

  bool releasePendingByAmount(double amount) {
    String? oldestId;
    DateTime? oldestAt;
    _pending.forEach((id, payment) {
      if ((payment.amount - amount).abs() >= 0.01) return;
      if (oldestAt == null || payment.at.isBefore(oldestAt!)) {
        oldestId = id;
        oldestAt = payment.at;
      }
    });
    if (oldestId == null) return false;
    _pending.remove(oldestId);
    return true;
  }

  double pendingTotal({String? excludingId, DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    _pending.removeWhere(
      (_, payment) => currentTime.difference(payment.at) > pendingTtl,
    );
    var total = 0.0;
    _pending.forEach((id, payment) {
      if (id != excludingId) total += payment.amount;
    });
    return total;
  }

  int get pendingCount => _pending.length;

  double tentativeRemaining({String? excludingId, DateTime? now}) {
    final remaining =
        remainingAmount - pendingTotal(excludingId: excludingId, now: now);
    return math.max(0.0, remaining).toDouble();
  }

  bool canAbsorbAnother(double amount, {String? excludingId, DateTime? now}) {
    if (!isActive || isExpired) return false;
    return tentativeRemaining(excludingId: excludingId, now: now) >= amount - 0.5;
  }

  Duration weakPairWindow(
    double amount, {
    // Keep aligned with PaymentIdentityMatcher.weakModalityWindow.
    Duration noBillWindow = const Duration(minutes: 3),
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    if (!isActive || isExpired) {
      final settledAt = _lastSettlementAt;
      if (settledAt != null &&
          currentTime.difference(settledAt) <= settledEchoWindow) {
        return coveredBillEchoWindow;
      }
      return noBillWindow;
    }
    return canAbsorbAnother(amount, now: currentTime)
        ? Duration.zero
        : coveredBillEchoWindow;
  }
}

class _PendingPayment {
  const _PendingPayment(this.amount, this.at);
  final double amount;
  final DateTime at;
}

enum BillMatchResult { noContext, exact, partial, suspicious, mismatch }
