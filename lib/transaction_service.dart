import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';  // ✅ Added for getAuthoritativeTime()

/// Transaction type classification
enum TransactionType {
  confirmed,      // Payment explicitly verified; see verificationStatus for method
  partial,        // Partial payment (e.g., ₹750 of ₹1000 bill)
  likely,         // Probable payment (notification-only, no SMS confirmation)
  walletCredit,   // Cashback/wallet load (NOT to be counted in revenue)
  pending,        // Payment initiated but not settled
  failed,         // Transaction failed or reversed
}

enum TransactionVerificationStatus {
  unverified,
  merchantConfirmed,
  providerVerified,
  manualEntry,
}

enum DetectedPaymentDirection { incoming, outgoing, pending, failed }

/// Transaction model
class Transaction {
  final String id;
  final String source; // SMS, UPI, Manual, WhatsApp, etc.
  final String? name;
  final String? phone;
  final double amount;
  final String type; // PAID, RECEIVED, PENDING (legacy), or use transactionType
  final TransactionType? transactionType; // New enum classification
  final String? reference; // Transaction ID from payment app
  final DateTime createdAt;
  final String? notes;
  final String? rawMessage;
  final bool isCashback; // Explicitly mark cashback to exclude from revenue
  final bool isWalletCredit; // Wallet top-up, not merchant revenue
  final TransactionVerificationStatus verificationStatus;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  Transaction({
    required this.id,
    required this.source,
    this.name,
    this.phone,
    required this.amount,
    required this.type,
    this.transactionType = TransactionType.pending,
    this.reference,
    required this.createdAt,
    this.notes,
    this.rawMessage,
    this.isCashback = false,
    this.isWalletCredit = false,
    this.verificationStatus = TransactionVerificationStatus.unverified,
    this.verifiedBy,
    this.verifiedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'name': name,
    'phone': phone,
    'amount': amount, // Store as double — avoids locale-specific string parse errors
    'type': type,
    'transaction_type': transactionType?.toString(),
    'reference': reference,
    'created_at': createdAt.toIso8601String(),
    'notes': notes,
    'raw_message': rawMessage,
    'is_cashback': isCashback,
    'is_wallet_credit': isWalletCredit,
    'verification_status': verificationStatus.name,
    'verified_by': verifiedBy,
    'verified_at': verifiedAt?.toIso8601String(),
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final txnTypeStr = json['transaction_type'] as String?;
    TransactionType? txnType;
    if (txnTypeStr != null) {
      // Handle both 'confirmed' and 'TransactionType.confirmed' formats
      final name = txnTypeStr.contains('.') ? txnTypeStr.split('.').last : txnTypeStr;
      try {
        txnType = TransactionType.values.byName(name);
      } catch (e) {
        // Leave null if unrecognized
      }
    }
    final verificationStatusName =
        json['verification_status']?.toString().split('.').last;
    var verificationStatus = TransactionVerificationStatus.unverified;
    for (final status in TransactionVerificationStatus.values) {
      if (status.name == verificationStatusName) {
        verificationStatus = status;
        break;
      }
    }
    return Transaction(
      id: json['id'] as String,
      source: json['source'] as String? ?? 'Manual',
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      type: json['type'] as String? ?? 'PENDING',
      transactionType: txnType,
      reference: json['reference'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      notes: json['notes'] as String?,
      rawMessage: json['raw_message'] as String?,
      isCashback: json['is_cashback'] as bool? ?? false,
      isWalletCredit: json['is_wallet_credit'] as bool? ?? false,
      verificationStatus: verificationStatus,
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.tryParse(json['verified_at'].toString()),
    );
  }

  Transaction copyWith({
    String? type,
    TransactionType? transactionType,
    TransactionVerificationStatus? verificationStatus,
    String? notes,
    String? verifiedBy,
    DateTime? verifiedAt,
  }) {
    return Transaction(
      id: id,
      source: source,
      name: name,
      phone: phone,
      amount: amount,
      type: type ?? this.type,
      transactionType: transactionType ?? this.transactionType,
      reference: reference,
      createdAt: createdAt,
      notes: notes ?? this.notes,
      rawMessage: rawMessage,
      isCashback: isCashback,
      isWalletCredit: isWalletCredit,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

/// Transaction Service - Handle storage and parsing
class TransactionService {
  static const String _transactionKey = 'transactions_v1';
  static Future<void> _saveQueue = Future<void>.value();

  static DetectedPaymentDirection classifyDetectedMessage(String message) {
    final text = message.toLowerCase();
    if (RegExp(
      r'\b(failed|declined|reversed|reversal|cancelled|canceled|refunded)\b|'
      r'\b(no|not|never|unable\s+to)\s+(?:payment\s+)?(?:received|credited|deposited)\b',
    ).hasMatch(text)) {
      return DetectedPaymentDirection.failed;
    }
    if (RegExp(
      r'\b(pending|processing|initiated|will\s+be\s+credited|to\s+be\s+credited)\b',
    ).hasMatch(text)) {
      return DetectedPaymentDirection.pending;
    }

    final incoming = RegExp(
      r'\b(credited|credit\s+(?:of|to|into|in|with)|received|deposited|'
      r'money\s+received|payment\s+received|amount\s+received|'
      r'added\s+to\s+(your\s+)?(account|wallet)|'
      r'sent\s+to\s+(you|your)|sent\s+you|paid\s+to\s+you|paid\s+you)\b',
    ).hasMatch(text);
    final outgoing = RegExp(
      r'\b(debited|debit|withdrawn|deducted|spent|purchase|sent\s+to\s+(?!you\b|your\b)|paid\s+to\s+(?!you\b|your\b)|transferred\s+to\s+(?!you\b|your\b))',
    ).hasMatch(text);
    if (incoming && outgoing) return DetectedPaymentDirection.pending;
    if (incoming) return DetectedPaymentDirection.incoming;
    if (outgoing) return DetectedPaymentDirection.outgoing;
    return DetectedPaymentDirection.pending;
  }

  static bool isEligibleForMerchantConfirmation(Transaction transaction) {
    return transaction.amount.isFinite &&
        transaction.amount > 0 &&
        transaction.type.toUpperCase() == 'RECEIVED' &&
        transaction.transactionType != TransactionType.failed &&
        transaction.transactionType != TransactionType.walletCredit &&
        !transaction.isCashback &&
        !transaction.isWalletCredit &&
        classifyDetectedMessage(transaction.rawMessage ?? '') ==
            DetectedPaymentDirection.incoming;
  }

  static TransactionType transactionTypeForDetectedMessage(String message) {
    switch (classifyDetectedMessage(message)) {
      case DetectedPaymentDirection.incoming:
        return TransactionType.likely;
      case DetectedPaymentDirection.outgoing:
        return TransactionType.pending;
      case DetectedPaymentDirection.pending:
        return TransactionType.pending;
      case DetectedPaymentDirection.failed:
        return TransactionType.failed;
    }
  }

  static String transactionDirectionForDetectedMessage(String message) {
    switch (classifyDetectedMessage(message)) {
      case DetectedPaymentDirection.incoming:
        return 'RECEIVED';
      case DetectedPaymentDirection.outgoing:
        return 'PAID';
      case DetectedPaymentDirection.failed:
        return 'FAILED';
      case DetectedPaymentDirection.pending:
        return 'PENDING';
    }
  }

  /// Load all transactions
  static Future<List<Transaction>> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_transactionKey) ?? '[]';
      final decoded = json.decode(raw) as List;
      return decoded
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      if (kDebugMode) print('❌ Error loading transactions: $e');
      return [];
    }
  }

  /// Save transaction
  static Future<void> saveTransaction(Transaction txn) {
    final operation = _saveQueue.then((_) => _saveTransaction(txn));
    _saveQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static Future<Transaction> confirmDetectedIncoming(
    Transaction transaction,
  ) async {
    if (!isEligibleForMerchantConfirmation(transaction)) {
      throw StateError(
        'Only an unambiguous incoming credit can be confirmed.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.get('user_id') ??
        prefs.get('userId') ??
        prefs.getString('email') ??
        prefs.getString('user_name');
    if (userId == null || userId.toString().trim().isEmpty) {
      throw StateError(
        'Sign in again before confirming a detected payment so the action can be attributed.',
      );
    }
    final currentTime = DateTime.now();
    final existingNotes = transaction.notes?.trim();
    final confirmed = transaction.copyWith(
      type: 'RECEIVED',
      transactionType: TransactionType.confirmed,
      verificationStatus: TransactionVerificationStatus.merchantConfirmed,
      verifiedBy: userId.toString(),
      verifiedAt: currentTime,
      notes: [
        if (existingNotes?.isNotEmpty == true) existingNotes,
        'Merchant-confirmed; not bank-verified.',
      ].join(' | '),
    );
    await saveTransaction(confirmed);
    return confirmed;
  }

  static Future<void> _saveTransaction(Transaction txn) async {
    _validateForPersistence(txn);
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactions = await loadTransactions();
      
      final existingIndex = transactions.indexWhere((existing) {
        if (existing.id == txn.id) return true;
        return txn.reference?.trim().isNotEmpty == true &&
            existing.reference == txn.reference &&
            (existing.amount - txn.amount).abs() < 0.001;
      });
      if (existingIndex >= 0) {
        final existing = transactions[existingIndex];
        if (existing.verificationStatus ==
                TransactionVerificationStatus.unverified &&
            txn.verificationStatus !=
                TransactionVerificationStatus.unverified) {
          transactions[existingIndex] = txn;
        } else {
          if (kDebugMode) print('⚠️ Transaction already exists: ${txn.id}');
          return;
        }
      } else {
        transactions.insert(0, txn);
      }

      final encoded = json.encode(transactions.map((t) => t.toJson()).toList());
      if (!await prefs.setString(_transactionKey, encoded)) {
        throw StateError('Transaction storage did not confirm the write.');
      }
      
      if (kDebugMode) print('✅ Transaction saved: ${txn.name} - ₹${txn.amount}');
    } catch (e) {
      if (kDebugMode) print('❌ Error saving transaction: $e');
      rethrow;
    }
  }

  static void _validateForPersistence(Transaction transaction) {
    if (transaction.id.trim().isEmpty ||
        !transaction.amount.isFinite ||
        transaction.amount <= 0) {
      throw StateError('A transaction requires a valid ID and positive amount.');
    }
    if (transaction.verificationStatus ==
            TransactionVerificationStatus.unverified ||
        transaction.verificationStatus ==
            TransactionVerificationStatus.merchantConfirmed &&
            (transaction.verifiedAt == null ||
                transaction.verifiedBy == null ||
                transaction.verifiedBy!.isEmpty)) {
      throw StateError(
        'Transactions require an explicit verification or manual-entry status.',
      );
    }
    if (transaction.verificationStatus ==
            TransactionVerificationStatus.merchantConfirmed &&
        (!isEligibleForMerchantConfirmation(transaction) ||
            transaction.transactionType != TransactionType.confirmed)) {
      throw StateError(
        'Only a clear incoming credit can be marked merchant-confirmed.',
      );
    }
    if (transaction.verificationStatus ==
            TransactionVerificationStatus.providerVerified &&
        (!isEligibleForMerchantConfirmation(transaction) ||
            transaction.transactionType != TransactionType.confirmed ||
            transaction.verifiedAt == null ||
            transaction.verifiedBy?.trim().isNotEmpty != true ||
            transaction.reference?.trim().isNotEmpty != true)) {
      throw StateError(
        'Provider-verified records must be confirmed incoming credits.',
      );
    }
  }

  /// Save multiple transactions
  static Future<void> saveTransactions(List<Transaction> txns) async {
    for (var txn in txns) {
      await saveTransaction(txn);
    }
  }

  /// Parse UPI notification (Google Pay, PhonePe, Paytm format)
  static Transaction? parseUpiNotification(String message, String source) {
    try {
      // Common formats:
      // "₹500 transferred to 8765432109"
      // "Payment received from Rahul - ₹1000"
      // "₹250 received to UPI ID"

      final amountRegex = RegExp(r'₹\s*([\d,]+\.?\d*)');
      final amountMatch = amountRegex.firstMatch(message);
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));

      // Extract phone/name pattern
      String? phone;
      String? name;

      // Pattern: "to 8765432109" or "from 8765432109"
      final phoneRegex = RegExp(r'(?:to|from|received from)\s*([0-9]{10})');
      final phoneMatch = phoneRegex.firstMatch(message);
      if (phoneMatch != null) {
        phone = phoneMatch.group(1);
      }

      // Pattern: "from Name" or "to Name"
      final nameRegex = RegExp(r'(?:from|to)\s+([A-Za-z\s]+)[\s-₹]');
      final nameMatch = nameRegex.firstMatch(message);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim();
      }

      final type = transactionDirectionForDetectedMessage(message);

      final referenceMatch = RegExp(
        r'(?:ref(?:erence)?|txn(?:\s*id)?|transaction\s*id)[:\s-]+([A-Z0-9-]+)',
        caseSensitive: false,
      ).firstMatch(message);
      final reference = referenceMatch?.group(1);

      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: source,
        name: name,
        phone: phone,
        amount: amount,
        type: type,
        transactionType: transactionTypeForDetectedMessage(message),
        reference: reference,
        createdAt: DateTime.now(),
        rawMessage: message,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to parse UPI: $e');
      return null;
    }
  }

  /// Parse SMS transaction (Bank notification)
  static Transaction? parseSmsBanking(String message) {
    try {
      // Format: "A/C xx1234 Debit ₹500 to MERCHANT SHOP - Ref: TXN123"
      // Format: "A/C xx1234 Credit ₹1000 from CUSTOMER"

      final amountRegex = RegExp(r'₹\s*([\d,]+\.?\d*)');
      final amountMatch = amountRegex.firstMatch(message);
      if (amountMatch == null) return null;

      double amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));

      final type = transactionDirectionForDetectedMessage(message);

      // Extract name
      String? name;
      final nameRegex = RegExp(r'(?:to|from)\s+([A-Za-z\s]+)[\s-]');
      final nameMatch = nameRegex.firstMatch(message);
      if (nameMatch != null) {
        name = nameMatch.group(1)?.trim();
      }

      // Extract reference
      String? reference;
      final refRegex = RegExp(r'Ref\s*:\s*([A-Z0-9]+)');
      final refMatch = refRegex.firstMatch(message);
      if (refMatch != null) {
        reference = refMatch.group(1);
      }

      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        source: 'SMS_BANK',
        name: name,
        amount: amount,
        type: type,
        transactionType: transactionTypeForDetectedMessage(message),
        reference: reference,
        createdAt: DateTime.now(),
        rawMessage: message,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to parse SMS: $e');
      return null;
    }
  }

  static Future<double> getTodayTotal() async {
    final txns = await loadTransactions();
    final now = DateTime.now();
    return txns.where((t) {
      return t.createdAt.year == now.year &&
          t.createdAt.month == now.month &&
          t.createdAt.day == now.day &&
          !t.isCashback &&
          !t.isWalletCredit;
    }).fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Get today's revenue (confirmed + partial payments only)
  static Future<double> getTodayRevenue() async {
    final txns = await loadTransactions();

    // ✅ FIX: Use server time instead of device time (prevents fraud)
    final now = await SyncService.getAuthoritativeTime();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return txns.where((t) {
      return t.createdAt.isAfter(todayStart) &&
          t.createdAt.isBefore(todayEnd) &&
          t.type.toUpperCase() == 'RECEIVED' &&
          (t.transactionType == TransactionType.confirmed ||
              t.transactionType == TransactionType.partial) &&
          t.verificationStatus != TransactionVerificationStatus.unverified &&
          !t.isCashback &&
          !t.isWalletCredit;
    }).fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Get transactions by date range
  static Future<List<Transaction>> getTransactionsByRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final txns = await loadTransactions();
    return txns
        .where((t) => t.createdAt.isAfter(startDate) && t.createdAt.isBefore(endDate))
        .toList();
  }

  /// Delete transaction
  static Future<void> deleteTransaction(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txns = await loadTransactions();
      txns.removeWhere((t) => t.id == id);
      final encoded = json.encode(txns.map((t) => t.toJson()).toList());
      await prefs.setString(_transactionKey, encoded);
      if (kDebugMode) print('✅ Transaction deleted: $id');
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting transaction: $e');
    }
  }

  /// Update transaction — atomic in-place replace to avoid data loss
  static Future<void> updateTransaction(Transaction txn) async {
    _validateForPersistence(txn);
    try {
      final prefs = await SharedPreferences.getInstance();
      final txns = await loadTransactions();
      final idx = txns.indexWhere((t) => t.id == txn.id);
      if (idx >= 0) {
        txns[idx] = txn; // replace in-place
      } else {
        txns.add(txn); // not found — append
      }
      final encoded = json.encode(txns.map((t) => t.toJson()).toList());
      await prefs.setString(_transactionKey, encoded);
      if (kDebugMode) print('✅ Transaction updated: ${txn.id}');
    } catch (e) {
      if (kDebugMode) print('❌ Error updating transaction: $e');
    }
  }
}
