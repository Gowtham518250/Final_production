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
              .where(_isConfirmed)
              .toList(growable: false);
          final pendingEntries = entries.length - confirmedEntries.length;
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
                    title: const LiveTranslatedText('Confirmed receipts'),
                    subtitle: LiveTranslatedText(
                      '${confirmedEntries.length} confirmed · '
                      '$pendingEntries awaiting verification',
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
                      final confirmed = _isConfirmed(entry);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: confirmed
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            child: Icon(
                              confirmed
                                  ? Icons.check_circle_outline
                                  : Icons.pending_outlined,
                              color: confirmed ? Colors.green : Colors.orange,
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
                            confirmed ? 'Confirmed' : 'Pending verification',
                            style: TextStyle(
                              color: confirmed ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                const LiveTranslatedText(
                  'Detected incoming credits are saved on this device. '
                  'Only confirmed receipts are included in the total; '
                  'verify pending payments before treating them as paid.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isConfirmed(Map<String, dynamic> entry) =>
      entry['status'] == 'CONFIRMED' ||
      (entry['status'] == null && entry['verified'] == true);

  String _formatTime(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Time unavailable';
    return DateFormat.yMMMd().add_jm().format(date);
  }
}
