import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';
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

  Future<void> _dismissEntry(Map<String, dynamic> entry) async {
    final key = entry['_history_key']?.toString() ?? '';
    if (key.isEmpty) return;

    final dismissed = await OnlinePaymentHistoryService.dismissEntry(key);
    if (!mounted) return;

    if (dismissed) {
      setState(() => _history = OnlinePaymentHistoryService.load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LiveTranslatedText('Detection dismissed')),
      );
    }
  }

  String _currency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);
  }

  Widget _metric(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          LiveTranslatedText(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLabel({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: LiveTranslatedText(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF344054)),
        title: LiveTranslatedText(
          localizations.translate('Online Payment History'),
          style: const TextStyle(
            color: Color(0xFF1D2939),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh payment history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LiveTranslatedText(
                  'Could not load payment history: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
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
            (sum, entry) => sum + _amountOf(entry),
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF3156A6),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LiveTranslatedText(
                        'Merchant-confirmed receipts',
                        style: TextStyle(
                          color: Color(0xFF475467),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currency(confirmedTotal),
                        style: const TextStyle(
                          color: Color(0xFF1D2939),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _metric(
                            'Confirmed',
                            confirmedEntries.length,
                            const Color(0xFF16836B),
                          ),
                          _metric(
                            'Pending',
                            pendingEntries,
                            const Color(0xFFB54708),
                          ),
                          _metric(
                            'Auto-accepted',
                            automaticEntries,
                            const Color(0xFF3156A6),
                          ),
                          _metric(
                            'Conflicts',
                            conflictEntries,
                            const Color(0xFFB42318),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const LiveTranslatedText(
                  'Payment activity',
                  style: TextStyle(
                    color: Color(0xFF1D2939),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 34,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 34,
                          color: Color(0xFF98A2B3),
                        ),
                        SizedBox(height: 10),
                        LiveTranslatedText(
                          'No incoming payment detections have been recorded yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...entries.map(_buildPaymentEntry),
                const SizedBox(height: 14),
                const LiveTranslatedText(
                  'Only merchant-confirmed receipts are included in the total. '
                  'Auto-accepted detections are detector decisions, not bank '
                  'verification. Conflicts remain excluded until reviewed.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentEntry(Map<String, dynamic> entry) {
    final confirmed = _isMerchantConfirmed(entry);
    final automatic = _isAutomaticAccepted(entry);
    final conflict = _isConflict(entry);

    final Color statusColor = conflict
        ? const Color(0xFFB42318)
        : confirmed
        ? const Color(0xFF16836B)
        : automatic
        ? const Color(0xFF3156A6)
        : const Color(0xFFB54708);
    final String statusText = conflict
        ? 'Review conflict'
        : confirmed
        ? 'Merchant-confirmed'
        : automatic
        ? 'Auto-accepted'
        : 'Pending review';
    final IconData statusIcon = conflict
        ? Icons.warning_amber_rounded
        : confirmed
        ? Icons.verified_outlined
        : automatic
        ? Icons.auto_awesome_outlined
        : Icons.pending_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currency(_amountOf(entry)),
                      style: const TextStyle(
                        color: Color(0xFF1D2939),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LiveTranslatedText(
                      (entry['app'] ?? 'Online payment').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF475467),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    LiveTranslatedText(
                      _formatTime(entry['timestamp']),
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusLabel(
                label: statusText,
                color: statusColor,
                icon: statusIcon,
              ),
            ],
          ),
          if (!confirmed) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _dismissEntry(entry),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const LiveTranslatedText('Dismiss detection'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF667085),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _amountOf(Map<String, dynamic> entry) {
    final value = entry['amount'];
    return value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
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
