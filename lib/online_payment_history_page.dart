import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'live_translated_text.dart';
import 'online_payment_history_service.dart';

class OnlinePaymentHistoryPage extends StatefulWidget {
  const OnlinePaymentHistoryPage({super.key});

  @override
  State<OnlinePaymentHistoryPage> createState() =>
      _OnlinePaymentHistoryPageState();
}

class _OnlinePaymentHistoryPageState extends State<OnlinePaymentHistoryPage> {
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _history = OnlinePaymentHistoryService.load();
  }

  Future<void> _refresh() async {
    setState(() => _history = OnlinePaymentHistoryService.load());
    await _history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LiveTranslatedText('Online Payment History'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: LiveTranslatedText(
                'Could not load payment history: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          final confirmedEntries = entries
              .where(_isMerchantConfirmed)
              .toList(growable: false);
          final automaticEntries = entries.where(_isAutomaticAccepted).length;
          final conflictEntries = entries.where(_isConflict).length;
          final pendingEntries = entries
              .where(
                (entry) =>
                    !_isMerchantConfirmed(entry) &&
                    !_isAutomaticAccepted(entry) &&
                    !_isConflict(entry),
              )
              .length;
          final confirmedTotal = confirmedEntries.fold<double>(
            0,
            (sum, entry) => sum + ((entry['amount'] as num?)?.toDouble() ?? 0),
          );
          if (entries.isEmpty) {
            return const Center(
              child: LiveTranslatedText(
                'No incoming payment detections have been recorded yet.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                    ),
                    title: const LiveTranslatedText('Merchant-confirmed receipts'),
                    subtitle: LiveTranslatedText(
                      '${confirmedEntries.length} merchant-confirmed · '
                      '$automaticEntries auto-accepted · '
                      '$pendingEntries pending · '
                      '$conflictEntries reference conflicts',
                    ),
                    trailing: Text(
                      NumberFormat.currency(
                        locale: 'en_IN',
                        symbol: '₹',
                        decimalDigits: 2,
                      ).format(confirmedTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in entries)
                  Builder(
                    builder: (context) {
                      final confirmed = _isMerchantConfirmed(entry);
                      final automatic = _isAutomaticAccepted(entry);
                      final conflict = _isConflict(entry);
                      final statusColor = conflict
                          ? Colors.red
                          : confirmed
                          ? Colors.green
                          : automatic
                          ? Colors.blue
                          : Colors.orange;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: conflict
                                ? Colors.red.shade50
                                : confirmed
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            child: Icon(
                              conflict
                                  ? Icons.warning_amber_rounded
                              : confirmed
                              ? Icons.check_circle_outline
                              : automatic
                              ? Icons.auto_awesome_outlined
                              : Icons.pending_outlined,
                              color: statusColor,
                            ),
                          ),
                          title: Text(
                            NumberFormat.currency(
                              locale: 'en_IN',
                              symbol: '₹',
                              decimalDigits: 2,
                            ).format(
                              (entry['amount'] as num?)?.toDouble() ?? 0,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: LiveTranslatedText(
                            '${entry['app'] ?? 'Online payment'} · '
                            '${_formatTime(entry['timestamp'])}',
                          ),
                          trailing: LiveTranslatedText(
                            conflict
                                ? 'Review conflict'
                              : confirmed
                              ? 'Merchant-confirmed'
                              : automatic
                              ? 'Auto-accepted · verify if needed'
                              : 'Pending review',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                const LiveTranslatedText(
                  'This history is stored on this device. Only merchant-confirmed '
                  'receipts are included in the total. Auto-accepted detections '
                  'are detector decisions, not merchant confirmation or bank '
                  'verification; reference conflicts are excluded until reviewed.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isMerchantConfirmed(Map<String, dynamic> entry) =>
      (entry['status'] == 'CONFIRMED' && entry['merchant_confirmed'] == true) ||
      (entry['status'] == null &&
          (entry['merchant_confirmed'] == true || entry['verified'] == true));

  bool _isAutomaticAccepted(Map<String, dynamic> entry) =>
      entry['status'] == 'AUTO_ACCEPTED' ||
      (entry['confirmation_mode'] == 'automatic' &&
          entry['merchant_confirmed'] != true);

  bool _isConflict(Map<String, dynamic> entry) =>
      entry['status'] == 'CONFLICT_REVIEW';

  String _formatTime(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Time unavailable';
    return DateFormat.yMMMd().add_jm().format(date);
  }
}
