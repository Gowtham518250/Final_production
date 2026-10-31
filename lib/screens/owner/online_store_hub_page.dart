import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../live_translated_text.dart';
import '../../online_order_service.dart';
import '../../online_store_service.dart';
import '../../visual_widgets.dart' show AppColors;

const Color _ink = Color(0xFF0F172A);
const Color _inkSoft = Color(0xFF475569);
const Color _line = Color(0xFFCBD5E1);
const Color _page = Color(0xFFF1F5F9);

TextStyle _t(double size, {FontWeight weight = FontWeight.w500, Color color = _ink}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

String formatHubRupees(num value) =>
    '\u20B9${NumberFormat.decimalPattern('en_IN').format(value.round())}';

enum OnlineStoreStatus { checking, live, offline, unknown }

class OnlineHubStats {
  const OnlineHubStats({required this.pending, required this.todayOrders, required this.todayPaid, required this.todayRevenue, required this.totalOrders, required this.totalPaid, required this.totalRevenue});
  final int pending, todayOrders, todayPaid, totalOrders, totalPaid;
  final double todayRevenue, totalRevenue;
  factory OnlineHubStats.fromAnalytics(Map<String, dynamic> m) {
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return OnlineHubStats(pending: i('pending'), todayOrders: i('todayCount'), todayPaid: i('todayPaidCount'), todayRevenue: d('todayRevenue'), totalOrders: i('totalCount'), totalPaid: i('totalPaidCount'), totalRevenue: d('totalRevenue'));
  }
}

class OnlineStoreHubPage extends StatefulWidget {
  const OnlineStoreHubPage({super.key});
  @override
  State<OnlineStoreHubPage> createState() => _OnlineStoreHubPageState();
}

class _OnlineStoreHubPageState extends State<OnlineStoreHubPage> {
  bool _loading = true;
  bool _loadFailed = false;
  bool? _storeLive;
  OnlineHubStats? _stats;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    var failed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = (prefs.getInt('user_id') ?? prefs.getInt('userId') ?? 0).toString();
      final values = await Future.wait<Map<String, dynamic>>([OnlineStoreService.getOnlineSettings(), OnlineOrderService.getAnalytics(shopId)]);
      final settings = values[0];
      final analytics = values[1];
      final settingsOk = settings['success'] == true;
      final analyticsOk = analytics['available'] == true;
      failed = !settingsOk || !analyticsOk;
      if (!mounted) return;
      setState(() {
        if (settingsOk) _storeLive = settings['is_online_store_enabled'] == true;
        if (analyticsOk) _stats = OnlineHubStats.fromAnalytics(analytics);
      });
    } catch (e) { failed = true; debugPrint('Online store hub refresh failed: $e'); }
    finally { if (mounted) setState(() { _loading = false; _loadFailed = failed; }); }
  }

  Future<void> _open(String route) async { await Navigator.pushNamed(context, route); if (mounted) _load(); }

  @override
  Widget build(BuildContext context) {
    final status = _storeLive == null ? (_loading ? OnlineStoreStatus.checking : OnlineStoreStatus.unknown) : (_storeLive! ? OnlineStoreStatus.live : OnlineStoreStatus.offline);
    return OnlineStoreHubView(status: status, stats: _stats, loading: _loading, loadFailed: _loadFailed, onRefresh: _load, onOpenOrders: () => _open('/online-orders'), onOpenInventory: () => _open('/inventory'), onOpenSetup: () => _open('/online-store-manager'));
  }
}

class OnlineStoreHubView extends StatelessWidget {
  const OnlineStoreHubView({super.key, required this.status, required this.stats, required this.loading, required this.loadFailed, required this.onRefresh, required this.onOpenOrders, required this.onOpenInventory, required this.onOpenSetup});
  final OnlineStoreStatus status;
  final OnlineHubStats? stats;
  final bool loading, loadFailed;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenOrders, onOpenInventory, onOpenSetup;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final live = status == OnlineStoreStatus.live;
    final statusLabel = status == OnlineStoreStatus.checking ? 'CHECKING' : status == OnlineStoreStatus.unknown ? 'STATUS UNKNOWN' : live ? 'LIVE' : 'OFFLINE';
    final headline = status == OnlineStoreStatus.checking ? 'Checking your online store…' : status == OnlineStoreStatus.unknown ? 'Online store status unavailable' : live ? 'Your online store is LIVE' : 'Your online store is OFFLINE';
    Widget metric(String label, String value, IconData icon) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _inkSoft), const SizedBox(height: 16), Text(value, style: _t(19, weight: FontWeight.w800)), const SizedBox(height: 4), Text(label, style: _t(11, color: _inkSoft))]));
    Widget action(IconData icon, String title, String subtitle, VoidCallback tap) => Material(color: Colors.white, borderRadius: BorderRadius.circular(17), child: InkWell(onTap: tap, borderRadius: BorderRadius.circular(17), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(17)), child: Row(children: [Icon(icon, color: _ink, size: 26), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _t(14, weight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: _t(11, color: _inkSoft))])), const Icon(Icons.chevron_right_rounded)]))));
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: _ink, elevation: 0, title: Text('Online Store', style: _t(19, weight: FontWeight.w800)), actions: [IconButton(onPressed: loading ? null : () => onRefresh(), icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 8)]),
      body: RefreshIndicator(onRefresh: onRefresh, child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: live ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.storefront_rounded, color: live ? const Color(0xFF15803D) : _inkSoft)), const Spacer(), Text(statusLabel, style: _t(11, weight: FontWeight.w800, color: live ? const Color(0xFF166534) : _inkSoft))]),
          const SizedBox(height: 18),
          Text(headline, style: _t(21, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(live ? 'Customers can discover your shop and place online orders.' : 'Manage your online store settings and make it available to customers.', style: _t(13, color: _inkSoft)),
          if (loadFailed) ...[const SizedBox(height: 12), Text('Some information could not be refreshed. Pull down to try again.', style: _t(12, color: const Color(0xFFB45309)))],
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onOpenSetup, icon: const Icon(Icons.tune_rounded), label: Text(live ? 'Manage online store' : 'Set up online store'), style: FilledButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        ])),
        const SizedBox(height: 18),
        Text('Orders at a glance', style: _t(17, weight: FontWeight.w800)), const SizedBox(height: 10),
        Row(children: [Expanded(child: metric('Waiting orders', s?.pending.toString() ?? (loading ? '…' : '—'), Icons.pending_actions_rounded)), const SizedBox(width: 10), Expanded(child: metric('Today orders', s?.todayOrders.toString() ?? (loading ? '…' : '—'), Icons.shopping_bag_outlined))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: metric('Today revenue', s == null ? (loading ? '…' : '—') : formatHubRupees(s.todayRevenue), Icons.currency_rupee_rounded)), const SizedBox(width: 10), Expanded(child: metric('Total revenue', s == null ? (loading ? '…' : '—') : formatHubRupees(s.totalRevenue), Icons.trending_up_rounded))]),
        const SizedBox(height: 18),
        Text('Quick actions', style: _t(17, weight: FontWeight.w800)), const SizedBox(height: 10),
        action(Icons.receipt_long_rounded, 'View new orders', 'Review, accept, or reject customer orders', onOpenOrders), const SizedBox(height: 10),
        action(Icons.inventory_2_outlined, 'Manage inventory', 'Check products listed in your online store', onOpenInventory), const SizedBox(height: 10),
        action(Icons.settings_outlined, 'Store settings', 'Update availability and shop details', onOpenSetup),
        const SizedBox(height: 18),
        if (s != null) Text('${s.totalOrders} total orders • ${s.totalPaid} paid • ${s.todayPaid} paid today', style: _t(12, color: _inkSoft)),
        if (status == OnlineStoreStatus.unknown) Text('Statistics are hidden until the server confirms the latest values.', style: _t(12, color: _inkSoft)),
      ])),
    );
  }
}
