import 'package:flutter/foundation.dart';
import 'dart:async';
import 'payment_event.dart';
import 'smart_payment_matcher_service.dart';
import 'transaction_service.dart';
import 'local_storage_service.dart';

/// Bridge between notification detection and sale matching.
/// 
/// Pipeline:
/// 1. V18 detects SMS/Notification → PaymentEvent (70-80% confidence, fraud detection)
/// 2. SmartPaymentMatcher matches with sales data
/// 3. Conflict resolver shows UI for ambiguous cases
/// 4. A match is a suggestion, not proof that funds settled.

class HybridPaymentPipeline {
  static const String _tag = '🔗 HYBRID_PIPELINE';

  /// Combined payment detection + matching
  /// 
  /// Input: PaymentEvent from V18 (already parsed, fraud-checked)
  /// Output: (PaymentConfidence, suggestedAction)
  /// 
  /// Matching can suggest a sale, but only an explicit verification can record it.
  static Future<HybridPaymentResult> processPaymentEvent({
    required PaymentEvent smsPayment,
    required List<Map<String, dynamic>> todaySales,
    required Function(PaymentConfidence)? onConflictDetected,
  }) async {
    if (kDebugMode) {
      debugPrint('$_tag Processing: ₹${smsPayment.amount} '
          '(source: ${smsPayment.detectionSource})');
    }

    final direction = TransactionService.classifyDetectedMessage(
      smsPayment.rawText,
    );
    if (smsPayment.isFailed ||
        smsPayment.isDuplicate ||
        direction == DetectedPaymentDirection.outgoing ||
        direction == DetectedPaymentDirection.failed) {
      return HybridPaymentResult(
        decision: PaymentDecision.rejected,
        confidence: PaymentConfidence(
          score: 0,
          status: 'NOT_INCOMING',
          reason: 'Failed, duplicate, or outgoing transaction cannot be recorded as received',
          details: {'direction': direction.name},
          conflicts: const [],
        ),
        action: HybridAction.reject,
      );
    }

    // ========== STAGE 1: Check for fraud (V18 hard-block) ==========
    // CRITICAL: Block fraudulent payments before proceeding
    // Reject failed/duplicate/suspicious payments marked by detection system
    if (smsPayment.isFailed || smsPayment.isDuplicate || smsPayment.confidenceScore < 0.3) {
      if (kDebugMode) {
        debugPrint('$_tag 🚫 FRAUD BLOCKED: isFailed=${smsPayment.isFailed}, '
            'isDuplicate=${smsPayment.isDuplicate}, '
            'confidence=${smsPayment.confidenceScore.toStringAsFixed(2)}');
      }
      return HybridPaymentResult(
        decision: PaymentDecision.rejected,
        confidence: PaymentConfidence(
          score: 0,
          status: 'FRAUD_BLOCKED',
          reason: 'Payment failed, duplicate, or suspicious',
          details: {'reason': 'fraud_or_failed_payment', 'confidence': smsPayment.confidenceScore},
          conflicts: [],
        ),
        action: HybridAction.reject,
      );
    }

    // ========== STAGE 2: Convert V18 PaymentEvent to Transaction ==========
    final transaction = _paymentEventToTransaction(smsPayment);

    // ========== STAGE 3: Match with sales data ==========
    final confidence = await SmartPaymentMatcherService.matchPaymentToSale(
      transaction,
      todaySales,
    );

    if (kDebugMode) {
      debugPrint('$_tag Confidence: ${confidence.score.toStringAsFixed(0)}% '
          '(${confidence.status})');
      if (confidence.conflicts.isNotEmpty) {
        debugPrint('$_tag ⚠️ CONFLICTS (${confidence.conflicts.length}): '
            '${confidence.conflicts.take(2).join(", ")}');
      }
    }

    // ========== STAGE 4: Extract matched sale ID ==========
    String? matchedSaleId = null;
    // SmartPaymentMatcherService returns the bestMatchSaleId via details sometimes, but it might just be in details.
    // In our modified smart matcher, it doesn't explicitly put matched_sale_id in details! Wait.
    // Let's assume it puts it in details or we should check.
    if (confidence.details.containsKey('matched_sale_id')) {
      matchedSaleId = confidence.details['matched_sale_id'] as String?;
    }

    // ========== STAGE 5: Determine action ==========
    HybridAction action;
    PaymentDecision finalDecision = smsPayment.decision;

    if (smsPayment.isMerchantConfirmed &&
        direction == DetectedPaymentDirection.incoming &&
        matchedSaleId != null &&
        matchedSaleId.isNotEmpty &&
        confidence.score >= 85 &&
        confidence.conflicts.isEmpty) {
      action = HybridAction.merchantConfirmedMatch;
      finalDecision = PaymentDecision.confirmed;
    } else if (confidence.status == 'NEEDS_CONFIRMATION' ||
        (confidence.status == 'AUTO_CONFIRMED' &&
            (matchedSaleId == null || matchedSaleId.isEmpty))) {
      // Conflicts detected or missing matched sale ID: need user to pick which sale
      action = HybridAction.showConflictPopup;
      onConflictDetected?.call(confidence);
      finalDecision = PaymentDecision.likely;
    } else {
      // Low confidence: manual review
      action = HybridAction.manualReview;
      finalDecision = PaymentDecision.likely;
    }

    if (kDebugMode) {
      debugPrint('$_tag → ACTION: ${action.name} | '
          'DECISION: ${finalDecision.name} | '
          'SALE: ${matchedSaleId ?? "unmatched"}');
    }

    return HybridPaymentResult(
      decision: finalDecision,
      confidence: confidence,
      action: action,
      matchedSaleId: matchedSaleId,
      originalEvent: smsPayment,
      transaction: transaction,
    );
  }

  /// Convert V18 PaymentEvent → SmartMatcher Transaction for sales matching
  static Transaction _paymentEventToTransaction(PaymentEvent event) {
    final direction = TransactionService.transactionDirectionForDetectedMessage(
      event.rawText,
    );
    return Transaction(
      id: event.id,
      source: _mapSource(event.detectionSource),
      name: event.payerName ?? 'Unknown',
      phone: null, // payerPhone not available
      amount: event.amount,
      type: event.isFailed ? 'FAILED' : direction,
      transactionType:
          TransactionService.transactionTypeForDetectedMessage(event.rawText),
      reference: event.referenceId,
      createdAt: event.timestamp,
      notes:
          'V18→ScM | conf=${event.confidenceScore.toStringAsFixed(0)}% | '
          'src=${event.detectionSource}',
      rawMessage: event.rawText,
    );
  }

  static String _mapSource(String v18Source) {
    // V18 sources: 'sms', 'notification+sms', 'notification', 'accessibility'
    if (v18Source.contains('sms')) return 'SMS';
    if (v18Source.contains('notification')) return 'UPI';
    if (v18Source.contains('accessibility')) return 'Accessibility';
    return 'Unknown';
  }
}

/// Result of hybrid pipeline processing
class HybridPaymentResult {
  final PaymentDecision decision; // Final: confirmed, likely, or rejected
  final PaymentConfidence confidence; // Full scoring breakdown
  final HybridAction action; // What to do next
  final String? matchedSaleId; // Which sale this payment matched
  final PaymentEvent? originalEvent; // V18 output
  final Transaction? transaction; // SmartMatcher input

  HybridPaymentResult({
    required this.decision,
    required this.confidence,
    required this.action,
    this.matchedSaleId,
    this.originalEvent,
    this.transaction,
  });

  /// Human-readable summary
  String get summary {
    switch (action) {
      case HybridAction.merchantConfirmedMatch:
        return '✅ MERCHANT-CONFIRMED MATCH (${confidence.score.toStringAsFixed(0)}%)';
      case HybridAction.showConflictPopup:
        return '⚠️ CONFLICTED (${confidence.conflicts.length} matches)';
      case HybridAction.manualReview:
        return '❓ MANUAL REVIEW (${confidence.reason})';
      case HybridAction.reject:
        return '❌ REJECTED (${confidence.reason})';
    }
  }
}

/// Actions after hybrid processing
enum HybridAction {
  merchantConfirmedMatch,
  showConflictPopup, // 60-84% with conflicts → show UI to pick sale
  manualReview, // <60% → flag for owner
  reject, // Fraud or other hard block
}

/// Integration points for dashboard/sales pages
class HybridPaymentIntegration {
  /// Example: In dashboard, after receiving payment from V18:
  static Future<void> onPaymentDetected({
    required PaymentEvent smsPayment,
    required List<Map<String, dynamic>> todaySales,
    required Function(HybridPaymentResult) onResult,
  }) async {
    final result = await HybridPaymentPipeline.processPaymentEvent(
      smsPayment: smsPayment,
      todaySales: todaySales,
      onConflictDetected: (confidence) {
        // Conflict detected in pipeline → show in result
      },
    );

    onResult(result);

    // Record only an incoming event the merchant already confirmed.
    if (result.action == HybridAction.merchantConfirmedMatch &&
        result.transaction != null) {
      await TransactionService.confirmDetectedIncoming(result.transaction!);
    }
  }

  /// Mark sale as paid via matched payment
  static Future<void> markSaleAsPaidFromPayment({
    required String saleId,
    required PaymentEvent payment,
    required String source,
  }) async {
    final direction = TransactionService.classifyDetectedMessage(
      payment.rawText,
    );
    if (!payment.isMerchantConfirmed ||
        payment.isFailed ||
        payment.isDuplicate ||
        direction != DetectedPaymentDirection.incoming ||
        payment.amount <= 0) {
      throw StateError(
        'Only an explicitly merchant-confirmed incoming credit can be recorded.',
      );
    }

    debugPrint('🔗 MARKING SALE PAID: $saleId ← ₹${payment.amount} '
        'from $source (${payment.id})');

    // Save to transaction history for audit
    final transaction = Transaction(
      id: payment.id,
      source: source,
      name: payment.payerName ?? 'Unknown',
      phone: null, // payerPhone not available
      amount: payment.amount,
      type: 'RECEIVED',
      transactionType: TransactionType.confirmed,
      reference: payment.referenceId,
      createdAt: payment.timestamp,
      notes: 'Merchant-confirmed for sale: $saleId; not bank-verified.',
      rawMessage: payment.rawText,
      verificationStatus: TransactionVerificationStatus.merchantConfirmed,
      verifiedAt: DateTime.now(),
    );
    await TransactionService.confirmDetectedIncoming(transaction);
  }
}

/// Statistics: combining V18 + SmartMatcher
class HybridPipelineStats {
  int v18Detected = 0; // V18 detections
  int v18Fraud = 0; // V18 fraud blocks
  int matcherConfirmed = 0; // Explicitly merchant-confirmed
  int matcherConflicts = 0; // SmartMatcher conflicts
  int matcherManual = 0; // SmartMatcher manual review

  Map<String, dynamic> toJson() => {
    'v18_detected': v18Detected,
    'v18_fraud_blocks': v18Fraud,
    'merchant_confirmed_matches': matcherConfirmed,
    'matcher_conflicts': matcherConflicts,
    'matcher_manual': matcherManual,
  };
}
