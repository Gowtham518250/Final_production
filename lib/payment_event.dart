// =============================================================================
// payment_event.dart  –  V5 MERCHANT GRADE
// Immutable data model for every detected payment event.
// Fingerprint uses UTR as primary key; falls back to HMAC-safe hash.
// =============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum PaymentApp {
  googlePay,
  phonePe,
  paytm,
  amazonPay,
  bhim,
  whatsappPay,
  cred,
  payzapp,
  icici,
  sbiYono,
  axis,
  hdfc,
  bankSms,
  bankApp,
  unknown,
}

enum PaymentDecision { confirmed, likely, rejected }

enum PaymentVerificationStatus { unverified, merchantConfirmed }

enum PaymentTransactionDirection { incomingCredit, outgoingDebit, unknown }

/// Confidence tier mapped from numeric score for human-readable logging.
enum ConfidenceTier { high, medium, low, rejected }

class PaymentEvent {
  // ── Core Fields ─────────────────────────────────────────────────────────────
  final double amount;
  final DateTime timestamp;
  final PaymentApp app;

  // ── Metadata ─────────────────────────────────────────────────────────────────
  final String? payerName;
  final String? referenceId; // UTR / 12-digit transaction ID
  final String? vpa; // UPI Virtual Payment Address (payer@bank)
  final String? accountSuffix; // Last 4 digits of bank account
  final String? bankName; // Resolved bank name where possible
  final String id;
  final PaymentDecision decision;

  // ── Status Flags ─────────────────────────────────────────────────────────────
  final bool isFailed;
  final bool isDuplicate;
  final bool isPartialPayment;
  final double remainingAmount; // Only meaningful when isPartialPayment = true
  // True only when the detector matched this event to the currently expected bill.
  final bool isBillMatch;

  // ── Debug / Audit ─────────────────────────────────────────────────────────────
  final String rawText;
  final double confidenceScore; // 0.0 – 1.0
  final String detectionSource; // "notification" | "sms" | "accessibility"
  final PaymentVerificationStatus verificationStatus;
  final PaymentTransactionDirection direction;

  // ── PRODUCTION HARDENING: IDEMPOTENCY & SYNC ──
  final String? saleId; // FIX 4: Mapping paymentId -> saleId
  final int version; // FIX 10: Versioning for conflict resolution
  final DateTime updatedAt;

  PaymentEvent({
    required this.amount,
    required this.timestamp,
    required this.app,
    this.payerName,
    this.referenceId,
    this.vpa,
    this.accountSuffix,
    this.bankName,
    this.isFailed = false,
    this.isDuplicate = false,
    this.isPartialPayment = false,
    this.remainingAmount = 0.0,
    this.isBillMatch = false,
    this.rawText = '',
    this.confidenceScore = 0.0,
    this.detectionSource = 'notification',
    this.verificationStatus = PaymentVerificationStatus.unverified,
    this.direction = PaymentTransactionDirection.unknown,
    this.saleId,
    this.version = 1,
    DateTime? updatedAt,
    String? id,
    this.decision = PaymentDecision.confirmed,
  }) : id = id ?? _genId(),
       updatedAt = updatedAt ?? DateTime.now();

  static String _genId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'pmt_$ts';
  }

  bool get isMerchantConfirmed =>
      decision == PaymentDecision.confirmed &&
      verificationStatus == PaymentVerificationStatus.merchantConfirmed;

  // ── Fingerprint ──────────────────────────────────────────────────────────────
  /// Primary key: UTR (100% collision-free).
  /// Fallback: MD5 of amount + payerName + rawText snippet.
  /// detectionSource intentionally excluded — same payment from two sources
  /// must hash identically for cross-source deduplication.
  /// Normalized reference used for transaction identity. Formatting characters
  /// and casing vary by source, so e.g. "utr-12 34" and "UTR1234" are equal.
  String? get normalizedReferenceId {
    final normalized = (referenceId ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Short placeholders are too weak to be a reliable transaction reference.
    if (normalized.length < 4 ||
        const {'NA', 'NAN', 'NONE', 'NULL', 'UNKNOWN', 'NOTAVAILABLE'}
            .contains(normalized)) {
      return null;
    }
    return normalized;
  }

  bool hasSameReferenceAs(PaymentEvent other) {
    final reference = normalizedReferenceId;
    return reference != null && reference == other.normalizedReferenceId;
  }

  /// A repeated reference with a different amount or a contradictory known
  /// direction is a conflict that needs review, not a new receipt.
  bool hasReferenceConflictWith(PaymentEvent other) {
    if (!hasSameReferenceAs(other)) return false;
    if ((amount - other.amount).abs() >= 0.01) return true;
    final currentDirection =
        direction == PaymentTransactionDirection.incomingCredit
        ? 'credit'
        : direction == PaymentTransactionDirection.outgoingDebit
        ? 'debit'
        : _transactionDirection(rawText);
    final otherDirection =
        other.direction == PaymentTransactionDirection.incomingCredit
        ? 'credit'
        : other.direction == PaymentTransactionDirection.outgoingDebit
        ? 'debit'
        : _transactionDirection(other.rawText);
    return currentDirection != 'unknown' &&
        otherDirection != 'unknown' &&
        currentDirection != otherDirection;
  }

  /// Accounting identity: a normalized reference is the primary key and is
  /// deliberately independent of amount, wording, timestamp, and source. This
  /// lets a repeated reference with a conflicting amount be recognized.
  ///
  /// Without a transaction reference we cannot prove two notifications describe
  /// the same transfer. Use this event's stable ID instead of merging payments
  /// merely because their amount and timestamps are similar. Such candidates
  /// must remain available for merchant review.
  String get fingerprint {
    final reference = normalizedReferenceId;
    if (reference != null) {
      return 'utr_${sha256.convert(utf8.encode(reference))}';
    }
    return 'event_$id';
  }

  static String _transactionDirection(String text) {
    final t = text.toLowerCase();

    final englishCredit = RegExp(
      r'\b(?:credited|credit|received|deposited|money\s+received|amount\s+received|payment\s+received|added\s+to|sent\s+to\s+(?:your|you)|sent\s+you|paid\s+to\s+(?:your|you)|paid\s+you|transferred\s+to\s+your|made\s+to\s+your|has\s+sent)\b',
    ).hasMatch(t);
    final incomingTransfer = RegExp(
      r'\b(?:sent|paid)\s+to\s+(?:your|you)\b|\b(?:sent|paid)\s+you\b|\bhas\s+sent\b',
    ).hasMatch(t);
    final incomingAccountTransfer = RegExp(
      r'\b(?:upi\s+)?transfer\s+from\s+.{1,60}?\s+to\s+'
      r'(?:your\s+)?(?:a\/c|account)\b',
      caseSensitive: false,
    ).hasMatch(t);
    final nativeCredit = RegExp(
      r'(जमा|क्रेडिट|प्राप्त|પૈસા મળ્યા|જમા|ક્રેડિટ|జమ|క్రెడిట్|అందింది|வரவு|பெறப்பட்டது|কয়েডিট|জমা|ক্রেডিট|জমা|ਜਮ੍ਹਾ|ਕ੍ਰੈਡਿਟ|വരവ്|ക്രെഡിറ്റ്|ലഭിച്ചു|ಜಮಾ|ಕ್ರೆಡಿಟ್)',
    ).hasMatch(t);
    final additionalNativeCredit = RegExp(
      r'(पैसे मिले|पैसा आया|मिळाले|जमा झाले|રકમ જમા|મળ્યા|મળ્યું|આવ્યા'
      r'|పేమెంట్ వచ్చింది|பணம் வரவு|வரவு வைக்கப்பட்டது|கிடைத்தது'
      r'|পেয়েছেন|পেয়েছেন|পাওয়া গেছে|পাওয়া গেছে|ਮਿਲੇ|ਮਿਲੀ'
      r'|നിക്ഷേപിച്ചു|ಪಾವತಿ ಬಂದಿದೆ|ಪಡೆದಿದೆ)',
    ).hasMatch(t);
    final credit =
        englishCredit ||
        nativeCredit ||
        additionalNativeCredit ||
        incomingAccountTransfer;

    final englishDebit = RegExp(
      r'\b(?:debited|debit|sent|you\s+sent|paid|payment\s+to|deducted|withdrawn|spent|purchase|transferred\s+to)\b',
    ).hasMatch(t);
    final nativeDebit = RegExp(
      r'(डेबिट|કાપવામાં આવ્યા|ડેબિટ|డెబిట్|పంపబడింది|பற்று|எடுக்கப்பட்டது|ডেবিট|কেটে নেওয়া|ਡੈਬਿਟ|ਕੱਟੇ|ഡെബിറ്റ്|പണം അയച്ചു|ಡೆബಿಟ್|ಕಡಿತ)',
    ).hasMatch(t);
    final additionalNativeDebit = RegExp(
      r'(निकाले गए|काट लिया|कटौती|काटा गया|भेजा गया|भुगतान किया|वजा झाले|कपात|काढले'
      r'|કપાઈ|ઉપાડ્યા|ચૂકવણી કરી|પૈસા મોકલ્યા'
      r'|తీసివేయబడింది|తీసేశారు|కట్ అయింది|చెల్లించబడింది'
      r'|பற்றானது|செலுத்தப்பட்டது|கழிக்கப்பட்டது|பணம் அனுப்பப்பட்டது'
      r'|কেটে নেওয়া|পাঠানো হয়েছে|পাঠানো হয়েছে|পরিশোধ হয়েছে|পরিশোধ হয়েছে'
      r'|ਕੱਟੀ|ਭੇਜੇ ਗਏ|ਭੁਗਤਾਨ ਕੀਤਾ|പിൻവലിച്ചു|കുറച്ചു'
      r'|ಹಣ ಕಳುಹಿಸಲಾಗಿದೆ|ಪಾವತಿಸಲಾಗಿದೆ)',
    ).hasMatch(t);
    final debit =
        !incomingTransfer &&
        !incomingAccountTransfer &&
        (englishDebit || nativeDebit || additionalNativeDebit);

    if (credit && !debit) return 'credit';
    if (debit && !credit) return 'debit';
    return 'unknown';
  }

  /// Maps any payment app to a broad family string so that a PhonePe
  /// notification and the corresponding bank SMS share the same fingerprint.
  static String _appFamily(PaymentApp app) {
    switch (app) {
      case PaymentApp.googlePay:
        return 'gpay';
      case PaymentApp.phonePe:
        return 'phonepe';
      case PaymentApp.paytm:
        return 'paytm';
      case PaymentApp.amazonPay:
        return 'amazon';
      case PaymentApp.bhim:
        return 'bhim';
      case PaymentApp.whatsappPay:
        return 'whatsapp';
      // Bank SMS and all bank apps share one family —
      // the SMS confirming a PhonePe payment comes from the bank, not PhonePe.
      // So we use a generic 'bank' bucket for all bank-sourced events.
      case PaymentApp.bankSms:
      case PaymentApp.bankApp:
      case PaymentApp.icici:
      case PaymentApp.sbiYono:
      case PaymentApp.axis:
      case PaymentApp.hdfc:
        return 'bank';
      default:
        return 'upi';
    }
  }

  /// Voice deduplication uses transaction identity, not notification wording,
  /// so alternate text for one credit or debit is announced only once.
  /// Voice-only heuristic: announcements can be deduplicated more loosely
  /// because suppressing a repeated sound does not change the ledger.
  String get voiceFingerprint {
    final reference = normalizedReferenceId;
    if (reference != null) {
      return 'voice_utr_${sha256.convert(utf8.encode(reference))}';
    }
    final dateBucket =
        '${timestamp.year.toString().padLeft(4, '0')}-'
        '${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')}';
    final fiveMinuteSlot = timestamp.hour * 12 + (timestamp.minute ~/ 5);
    final transactionDirection =
        this.direction == PaymentTransactionDirection.unknown
        ? _transactionDirection(rawText)
        : (this.direction == PaymentTransactionDirection.incomingCredit
            ? 'credit'
            : 'debit');
    final payload =
        '${amount.toStringAsFixed(2)}_${_appFamily(app)}_$transactionDirection_'
        '$dateBucket_$fiveMinuteSlot';
    return 'voice_${md5.convert(utf8.encode(payload))}';
  }

  ConfidenceTier get confidenceTier {
    if (confidenceScore >= 0.75) return ConfidenceTier.high;
    if (confidenceScore >= 0.50) return ConfidenceTier.medium;
    if (confidenceScore >= 0.35) return ConfidenceTier.low;
    return ConfidenceTier.rejected;
  }

  // ── Display Helpers ──────────────────────────────────────────────────────────
  String get appDisplayName {
    const names = {
      PaymentApp.googlePay: 'Google Pay',
      PaymentApp.phonePe: 'PhonePe',
      PaymentApp.paytm: 'Paytm',
      PaymentApp.amazonPay: 'Amazon Pay',
      PaymentApp.whatsappPay: 'WhatsApp Pay',
      PaymentApp.bhim: 'BHIM UPI',
      PaymentApp.cred: 'CRED',
      PaymentApp.payzapp: 'PayZapp',
      PaymentApp.icici: 'ICICI iMobile',
      PaymentApp.sbiYono: 'SBI YONO',
      PaymentApp.axis: 'Axis Mobile',
      PaymentApp.hdfc: 'HDFC Bank',
      PaymentApp.bankSms: 'Bank SMS',
    };
    return names[app] ?? 'UPI App';
  }

  String get amountDisplay =>
      amount % 1 == 0 ? '₹${amount.toInt()}' : '₹${amount.toStringAsFixed(2)}';

  PaymentEvent copyWith({
    double? amount,
    DateTime? timestamp,
    PaymentApp? app,
    String? payerName,
    String? referenceId,
    String? vpa,
    String? accountSuffix,
    String? bankName,
    bool? isFailed,
    bool? isDuplicate,
    bool? isPartialPayment,
    double? remainingAmount,
    bool? isBillMatch,
    String? rawText,
    double? confidenceScore,
    String? detectionSource,
    String? id,
    PaymentDecision? decision,
    PaymentVerificationStatus? verificationStatus,
    String? saleId,
    PaymentTransactionDirection? direction,
    int? version,
    DateTime? updatedAt,
  }) {
    return PaymentEvent(
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      app: app ?? this.app,
      payerName: payerName ?? this.payerName,
      referenceId: referenceId ?? this.referenceId,
      vpa: vpa ?? this.vpa,
      accountSuffix: accountSuffix ?? this.accountSuffix,
      bankName: bankName ?? this.bankName,
      isFailed: isFailed ?? this.isFailed,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      isPartialPayment: isPartialPayment ?? this.isPartialPayment,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      isBillMatch: isBillMatch ?? this.isBillMatch,
      rawText: rawText ?? this.rawText,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      detectionSource: detectionSource ?? this.detectionSource,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      direction: direction ?? this.direction,
      id: id ?? this.id,
      decision: decision ?? this.decision,
      saleId: saleId ?? this.saleId,
      // Every copy represents a new event revision unless the caller
      // explicitly supplies a version/timestamp from a durable source.
      version: version ?? this.version + 1,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // ── Serialisation ────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'app': app.name,
    'payerName': payerName,
    'referenceId': referenceId,
    'vpa': vpa,
    'accountSuffix': accountSuffix,
    'bankName': bankName,
    'isFailed': isFailed,
    'isDuplicate': isDuplicate,
    'isPartialPayment': isPartialPayment,
    'remainingAmount': remainingAmount,
    'isBillMatch': isBillMatch,
    'rawText': rawText,
    'confidenceScore': confidenceScore,
    'confidenceTier': confidenceTier.name,
    'detectionSource': detectionSource,
    'verificationStatus': verificationStatus.name,
    'direction': direction.name,
    'fingerprint': fingerprint,
    'decision': decision.name,
    'sale_id': saleId,
    'version': version,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory PaymentEvent.fromJson(Map<String, dynamic> json) => PaymentEvent(
    id: json['id'],
    amount: (json['amount'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    app: PaymentApp.values.firstWhere(
      (e) => e.name == json['app'],
      orElse: () => PaymentApp.unknown,
    ),
    payerName: json['payerName'],
    referenceId: json['referenceId'],
    vpa: json['vpa'],
    accountSuffix: json['accountSuffix'],
    bankName: json['bankName'],
    isFailed: json['isFailed'] ?? false,
    isDuplicate: json['isDuplicate'] ?? false,
    isPartialPayment: json['isPartialPayment'] ?? false,
    remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
    isBillMatch: json['isBillMatch'] ?? false,
    rawText: json['rawText'] ?? '',
    confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    detectionSource: json['detectionSource'] ?? 'notification',
    verificationStatus: PaymentVerificationStatus.values.firstWhere(
      (e) => e.name == json['verificationStatus'],
      orElse: () => PaymentVerificationStatus.unverified,
    ),
    direction: PaymentTransactionDirection.values.firstWhere(
      (e) => e.name == json['direction'],
      orElse: () => PaymentTransactionDirection.unknown,
    ),
    decision: PaymentDecision.values.firstWhere(
      (e) => e.name == json['decision'],
      orElse: () => PaymentDecision.confirmed,
    ),
    saleId: json['sale_id'],
    version: json['version'] ?? 1,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : null,
  );

  @override
  String toString() =>
      'PaymentEvent($amountDisplay via $appDisplayName'
      '${payerName != null ? " from $payerName" : ""}'
      '${referenceId != null ? " UTR:$referenceId" : ""}'
      ' conf:${(confidenceScore * 100).toStringAsFixed(0)}%)';
}

// =============================================================================
// FRAUD VERDICTS & ANALYSIS CLASSES
// =============================================================================

enum FraudVerdict {
  clean, // No fraud detected
  softPenaltyStructure, // Missing some fields
  softPenaltyUtr, // Missing UTR
  softPenaltyVpa, // VPA mismatch
  hardBlockUnicode, // Suspicious unicode
  hardBlockHtmlScript, // HTML/script injection
  hardBlockCyrillic, // Cyrillic characters
  hardBlockFutureTense, // Future tense (not yet paid)
  hardBlockContradiction, // Contradictory message
  hardBlockAmountCap, // Amount out of range
  hardBlockSenderSpoofed, // Sender spoofing detected
  bankVerifyFailed, // Bank verification failed
}

class FraudAnalysis {
  final FraudVerdict verdict;
  final double riskScore; // 0.0 - 1.0
  final String? reason;
  final bool isHardBlock; // Whether this is a hard block or soft penalty

  const FraudAnalysis({
    required this.verdict,
    required this.riskScore,
    this.reason,
    this.isHardBlock = false,
  });

  // Clean verdict singleton
  static const FraudAnalysis clean = FraudAnalysis(
    verdict: FraudVerdict.clean,
    riskScore: 0.0,
    reason: 'Payment looks legitimate',
    isHardBlock: false,
  );

  Map<String, dynamic> toJson() => {
    'verdict': verdict.name,
    'riskScore': riskScore,
    'reason': reason,
    'isHardBlock': isHardBlock,
  };
}
