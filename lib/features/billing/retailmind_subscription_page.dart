import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfsubscriptioncheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsubssession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../live_translated_text.dart';
import 'retailmind_billing_service.dart';

/// Owner-facing subscription management. All prices, tiers and entitlement
/// limits are loaded from the backend so plans can be added without an app release.
class RetailMindSubscriptionPage extends StatefulWidget {
  const RetailMindSubscriptionPage({super.key});

  @override
  State<RetailMindSubscriptionPage> createState() => _RetailMindSubscriptionPageState();
}

class _RetailMindSubscriptionPageState extends State<RetailMindSubscriptionPage> {
  late Future<List<RetailMindSubscriptionPlan>> _plansFuture;
  late Future<Map<String, dynamic>> _subscriptionFuture;
  late Future<AiUsageSnapshot> _usageFuture;
  String? _busyPlan;
  String _billingInterval = 'MONTHLY';
  final CFPaymentGatewayService _cashfree = CFPaymentGatewayService();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _plansFuture = RetailMindBillingService.fetchPlans();
    _subscriptionFuture = RetailMindBillingService.fetchCurrentSubscription();
    _usageFuture = RetailMindBillingService.fetchUsage();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_plansFuture, _subscriptionFuture, _usageFuture]);
  }

  void _onSubscriptionVerify(String subscriptionId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Mandate authorization completed. Retail Mind is confirming the subscription payment.'),
    ));
    _refresh();
  }

  void _onSubscriptionFailure(CFErrorResponse errorResponse, String data) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errorResponse.getMessage()),
    ));
  }

  Future<void> _selectPlan(RetailMindSubscriptionPlan plan) async {
    if (plan.code == 'FREE') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Free Starter is available automatically for every shop.'),
      ));
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cashfree subscription checkout is currently available in the Android/iOS app.'),
      ));
      return;
    }
    setState(() => _busyPlan = plan.code);
    try {
      final result = await RetailMindBillingService.createSubscription(
        plan.code,
        billingInterval: _billingInterval,
      );
      if (!mounted) return;
      final subscriptionId = (result['subscription_id'] ?? '').toString();
      final sessionId = (result['subscription_session_id'] ?? '').toString();
      if (subscriptionId.isEmpty || sessionId.isEmpty) {
        throw Exception('Cashfree did not return a valid subscription checkout session.');
      }
      final environment = (result['environment'] ?? 'sandbox').toString().toLowerCase() == 'production'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;
      final session = CFSubscriptionSessionBuilder()
          .setEnvironment(environment)
          .setSubscriptionId(subscriptionId)
          .setSubscriptionSessionId(sessionId)
          .build();
      final theme = CFThemeBuilder()
          .setNavigationBarBackgroundColorColor('#FFFFFF')
          .setNavigationBarTextColor('#172554')
          .build();
      final payment = CFSubscriptionPaymentBuilder()
          .setSession(session)
          .setTheme(theme)
          .build();
      _cashfree.setCallback(_onSubscriptionVerify, _onSubscriptionFailure);
      _cashfree.doPayment(payment);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const LiveTranslatedText('Retail Mind Plans'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh billing')],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _usageCard(),
            const SizedBox(height: 14),
            _currentSubscriptionCard(),
            const SizedBox(height: 22),
            Text('Choose a plan', style: GoogleFonts.inter(fontSize: 21, fontWeight: FontWeight.w800, color: const Color(0xFF172554))),
            const SizedBox(height: 5),
            Text('Plans and included features are managed by Retail Mind.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: ToggleButtons(
              isSelected: [_billingInterval == 'MONTHLY', _billingInterval == 'YEARLY'],
              onPressed: (index) => setState(() => _billingInterval = index == 0 ? 'MONTHLY' : 'YEARLY'),
              borderRadius: BorderRadius.circular(12),
              constraints: const BoxConstraints(minHeight: 40, minWidth: 112),
              children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Monthly')), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Yearly'))],
            )),
            const SizedBox(height: 12),
            FutureBuilder<List<RetailMindSubscriptionPlan>>(
              future: _plansFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
                if (snapshot.hasError) return _errorCard('Unable to load plans. Check your connection and refresh.');
                final plans = snapshot.data ?? const <RetailMindSubscriptionPlan>[];
                if (plans.isEmpty) return _errorCard('No plans are currently available. Please try again later.');
                return Column(children: plans.map(_planCard).toList());
              },
            ),
            const SizedBox(height: 14),
            const Text('All subscriptions are attached to the signed-in shop. Daily AI credits are shared by text and voice questions and reset according to the billing service clock.' , style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _usageCard() => FutureBuilder<AiUsageSnapshot>(
    future: _usageFuture,
    builder: (context, snapshot) {
      final usage = snapshot.data;
      final limit = usage?.limit ?? 0;
      final used = usage?.used ?? 0;
      final remaining = usage?.remaining ?? limit;
      final progress = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF273B92), Color(0xFF6246C7)]), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.auto_awesome_rounded, color: Colors.white), const SizedBox(width: 8), Text('Daily AI allowance', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), Text('$remaining left', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9BE7C4)))),
          const SizedBox(height: 9),
          Text('$used of $limit successful queries used today', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          if (snapshot.hasError) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Usage could not be refreshed.', style: TextStyle(color: Colors.white70, fontSize: 11))),
          if (usage?.resetsAt != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Resets ${DateFormat('dd MMM, hh:mm a').format(usage!.resetsAt!.toLocal())}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11))),
        ]),
      );
    },
  );

  Widget _currentSubscriptionCard() => FutureBuilder<Map<String, dynamic>>(
    future: _subscriptionFuture,
    builder: (context, snapshot) {
      final data = snapshot.data ?? const <String, dynamic>{};
      final status = (data['status'] ?? data['subscription_status'] ?? 'No active plan').toString().replaceAll('_', ' ');
      final plan = (data['plan_name'] ?? data['name'] ?? 'Subscription').toString();
      final renewal = data['next_charge_at'] ?? data['current_period_end'] ?? data['renewal_at'];
      return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E8F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.verified_user_outlined, color: Color(0xFF4454C7)), const SizedBox(width: 9), Text('Current subscription', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF172554))), const Spacer(), Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF596579)))]),
        const SizedBox(height: 8), Text(plan, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800)),
        if (renewal != null) Text('Next renewal: $renewal', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        if (snapshot.hasError) const Text('Subscription status is unavailable.', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
      ]));
    },
  );

  Widget _planCard(RetailMindSubscriptionPlan plan) {
    final interval = _billingInterval == 'YEARLY' ? 'year' : 'month';
    final price = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(plan.amountFor(_billingInterval));
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: plan.recommended ? const Color(0xFF7161D8) : const Color(0xFFE2E8F0), width: plan.recommended ? 1.7 : 1)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(plan.name, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF172554)))), if (plan.recommended) const Chip(label: Text('Popular', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)]),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(price, style: GoogleFonts.inter(fontSize: 29, fontWeight: FontWeight.w900, color: const Color(0xFF1E2D68))), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('/ $interval', style: const TextStyle(color: Color(0xFF64748B))))]),
      const SizedBox(height: 9),
      _featureLine(Icons.auto_awesome, '${plan.dailyAiQueryLimit} AI queries per day'),
      for (final feature in plan.features) _featureLine(Icons.check_circle_outline, feature),
      const SizedBox(height: 13),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: _busyPlan == null ? () => _selectPlan(plan) : null, child: _busyPlan == plan.code ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(plan.code == 'FREE' ? 'Included' : 'Continue to checkout'))),
    ]));
  }

  Widget _featureLine(IconData icon, String text) => Padding(padding: const EdgeInsets.only(top: 5), child: Row(children: [Icon(icon, size: 16, color: const Color(0xFF23845D)), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF53627C))))]));

  Widget _errorCard(String message) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Text(message, style: const TextStyle(color: Color(0xFF64748B))));
}
