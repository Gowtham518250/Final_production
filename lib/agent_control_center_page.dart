import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'agent_assistant_service.dart';

class AgentControlCenterPage extends StatefulWidget {
  const AgentControlCenterPage({super.key});
  @override
  State<AgentControlCenterPage> createState() => _AgentControlCenterPageState();
}

class _AgentControlCenterPageState extends State<AgentControlCenterPage>
    with SingleTickerProviderStateMixin {
  static const ink = Color(0xFF172554);
  static const muted = Color(0xFF64748B);
  static const purple = Color(0xFF5B4BF5);

  late final AnimationController _motion;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(String key) {
    final value = _data?[key];
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  bool _flag(Map<String, dynamic> map, String key) => map[key] == true;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AgentAssistantService.getControlCenter();
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _update(String key, bool value) async {
    if (_saving) return;
    final old = _data;
    final settings = _map('settings');
    setState(() {
      _saving = true;
      _error = null;
      _data = <String, dynamic>{
        ...?_data,
        'settings': <String, dynamic>{...settings, key: value},
      };
    });
    try {
      final data = await AgentAssistantService.updateSettings({key: value});
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() { _data = old; _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _map('plan');
    final settings = _map('settings');
    final access = _map('access');
    final entitlements = _map('entitlements');
    final usage = _map('usage');
    final platform = _map('platform');
    final assistantPlan = _flag(entitlements, 'assistant');
    final voicePlan = _flag(entitlements, 'voice');
    final actionsPlan = _flag(entitlements, 'actions');
    final active = _flag(access, 'assistant_enabled');
    final platformReady = _flag(platform, 'master_enabled') && _flag(platform, 'groq_configured');
    final planName = (plan['plan_name'] ?? 'Current plan').toString();
    final limit = (usage['daily_limit'] as num?)?.toInt() ?? 0;
    final used = (usage['used'] as num?)?.toInt() ?? 0;
    final reserved = (usage['reserved'] as num?)?.toInt() ?? 0;
    final remaining = (usage['remaining'] as num?)?.toInt() ?? math.max(0, limit - used - reserved).toInt();
    final progress = limit <= 0 ? 0.0 : ((used + reserved) / limit).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6FC),
        foregroundColor: ink,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agent Control Center', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Your shop assistant, your controls', style: TextStyle(fontSize: 10, color: muted)),
          ],
        ),
        actions: [
          IconButton(onPressed: _loading || _saving ? null : _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : RefreshIndicator(
              onRefresh: _load,
              color: purple,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _hero(platformReady, _flag(settings, 'assistant_enabled')),
                  const SizedBox(height: 15),
                  if (_error != null) _errorCard(_error!),
                  _usageCard(
                    planName: planName,
                    planCode: (plan['plan_code'] ?? 'FREE').toString(),
                    limit: limit,
                    used: used,
                    reserved: reserved,
                    remaining: remaining,
                    progress: progress,
                  ),
                  const SizedBox(height: 19),
                  _heading('YOUR ASSISTANT'),
                  const SizedBox(height: 8),
                  _setting(
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFF6256F5),
                    title: 'AI shop assistant',
                    description: 'Ask about sales, inventory, customers, invoices and shop operations.',
                    value: _flag(settings, 'assistant_enabled'),
                    unlocked: assistantPlan,
                    busy: _saving,
                    tag: assistantPlan ? 'Included in your plan' : 'Upgrade required',
                    onChanged: (v) => _update('assistant_enabled', v),
                  ),
                  const SizedBox(height: 10),
                  _setting(
                    icon: Icons.mic_rounded,
                    color: const Color(0xFF0891B2),
                    title: 'Voice conversations',
                    description: 'Speak naturally in supported Indian languages and hear spoken replies.',
                    value: _flag(settings, 'voice_enabled'),
                    unlocked: voicePlan && _flag(settings, 'assistant_enabled'),
                    busy: _saving,
                    tag: !voicePlan
                        ? 'PRO and above'
                        : (_flag(platform, 'sarvam_configured')
                            ? 'Voice plan access'
                            : 'Voice provider setup pending'),
                    onChanged: (v) => _update('voice_enabled', v),
                  ),
                  const SizedBox(height: 10),
                  _setting(
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFEA580C),
                    title: 'Business operations',
                    description: 'Prepare bills, stock, attendance and order actions for your review.',
                    value: _flag(settings, 'actions_enabled'),
                    unlocked: actionsPlan && _flag(settings, 'assistant_enabled'),
                    busy: _saving,
                    tag: actionsPlan ? 'Business plan access' : 'Business plan',
                    onChanged: (v) => _update('actions_enabled', v),
                  ),
                  if (!assistantPlan || !voicePlan || !actionsPlan)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/subscriptions'),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Explore plans and AI features'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: purple,
                          side: const BorderSide(color: Color(0xFFC7C9F7)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 19),
                  _heading('HOW ACCESS WORKS'),
                  const SizedBox(height: 8),
                  _step('01', 'Retail Mind platform',
                    platformReady
                      ? 'The AI platform and text provider are configured.'
                      : 'Platform setup is pending. Your preferences are remembered until it is enabled.',
                    platformReady),
                  _step('02', 'Your subscription',
                    assistantPlan
                      ? planName + ' includes ' + limit.toString() + ' AI requests per day.'
                      : 'Your current plan does not include the shop-data assistant.',
                    assistantPlan),
                  _step('03', 'Your choice',
                    _flag(settings, 'assistant_enabled')
                      ? 'You opted in. You can switch the assistant off at any time.'
                      : 'The assistant is off until you switch it on.',
                    _flag(settings, 'assistant_enabled')),
                  const SizedBox(height: 15),
                  _safetyCard(),
                  const SizedBox(height: 17),
                  FilledButton.icon(
                    onPressed: active ? () => Navigator.of(context).pushReplacementNamed('/chatbot-help') : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Open Retail Mind Assistant'),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back to Help & Support'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _hero(bool platformReady, bool optedIn) {
    final status = !platformReady ? 'PLATFORM SETUP PENDING' : optedIn ? 'YOUR ASSISTANT IS OPTED IN' : 'READY WHEN YOU ARE';
    final statusColor = !platformReady ? const Color(0xFFFDE68A) : optedIn ? const Color(0xFF86EFAC) : const Color(0xFFBAE6FD);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111A3C), Color(0xFF332B83), Color(0xFF4D46B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: const Color(0xFF352A9D).withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          const Text('RETAIL MIND / AI', style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
          const SizedBox(height: 8),
          const Text('One assistant. Your whole shop.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Choose how Retail Mind helps you run your day.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: statusColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
          ),
          SizedBox(width: 220, height: 205, child: _Orbit(controller: _motion)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFBFDBFE), size: 16),
              const SizedBox(width: 7),
              Text('Sensitive actions always wait for your confirmation.', style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _usageCard({
    required String planName,
    required String planCode,
    required int limit,
    required int used,
    required int reserved,
    required int remaining,
    required double progress,
  }) {
    final usageText = used.toString() + ' used' +
        (reserved > 0 ? ' · ' + reserved.toString() + ' processing' : '') +
        ' / ' + limit.toString();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFFE4E9F3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, color: purple),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planName, style: const TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(planCode + ' plan · Daily AI allowance', style: const TextStyle(color: muted, fontSize: 10)),
                  ],
                ),
              ),
              Text(limit > 0 ? remaining.toString() + ' left' : 'No AI allowance', style: const TextStyle(color: purple, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily usage', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(usageText, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: const Color(0xFFEEF0F8), valueColor: const AlwaysStoppedAnimation<Color>(purple)),
          ),
          const SizedBox(height: 8),
          const Text('Usage resets at midnight India Standard Time.', style: TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _setting({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool value,
    required bool unlocked,
    required bool busy,
    required String tag,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE4E9F3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: muted, fontSize: 10, height: 1.4)),
                const SizedBox(height: 8),
                Text(tag, style: TextStyle(color: unlocked ? color : muted, fontSize: 9, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(value: value, onChanged: unlocked && !busy ? onChanged : null, activeColor: color),
        ],
      ),
    );
  }

  Widget _step(String number, String title, String detail, bool completed) {
    final color = completed ? const Color(0xFF059669) : const Color(0xFF94A3B8);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE4E9F3))),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: completed ? Icon(Icons.check_rounded, color: color, size: 18) : Text(number, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(detail, style: const TextStyle(color: muted, fontSize: 10, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDDE3FF))),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: purple, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You stay in control', style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Retail Mind can prepare an action, but bills, stock changes, attendance corrections and order transitions still require your review and explicit confirmation.', style: TextStyle(color: muted, fontSize: 10, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _heading(String title) => Text(title, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2));

  Widget _errorCard(String message) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFFED7AA))),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF9A3412), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF9A3412), fontSize: 10))),
          ],
        ),
      );
}

class _Orbit extends StatelessWidget {
  const _Orbit({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final spin = reduced ? 0.0 : controller.value * math.pi * 2;
        final pulse = reduced ? 1.0 : 0.94 + 0.06 * math.sin(controller.value * math.pi * 4);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 154,
              height: 154,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF22D3EE).withValues(alpha: 0.16), const Color(0xFF5B4BF5).withValues(alpha: 0.02), Colors.transparent]),
              ),
            ),
            Transform.rotate(
              angle: spin * -0.35,
              child: Container(width: 168, height: 90, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF93C5FD).withValues(alpha: 0.40), width: 1.1), borderRadius: BorderRadius.circular(100))),
            ),
            Transform.rotate(
              angle: spin * 0.5,
              child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFA5B4FC).withValues(alpha: 0.36), width: 1))),
            ),
            Transform.rotate(
              angle: spin,
              child: SizedBox(
                width: 174,
                height: 174,
                child: Stack(
                  children: const [
                    Positioned(top: 2, left: 76, child: _OrbitNode(icon: Icons.inventory_2_rounded, color: Color(0xFF67E8F9))),
                    Positioned(bottom: 2, left: 76, child: _OrbitNode(icon: Icons.receipt_long_rounded, color: Color(0xFFC4B5FD))),
                    Positioned(left: 2, top: 76, child: _OrbitNode(icon: Icons.groups_rounded, color: Color(0xFF86EFAC))),
                    Positioned(right: 2, top: 76, child: _OrbitNode(icon: Icons.insights_rounded, color: Color(0xFFFDE68A))),
                  ],
                ),
              ),
            ),
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF8B85FF), Color(0xFF4F46E5), Color(0xFF27236F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: const Color(0xFF8B85FF).withValues(alpha: 0.42), blurRadius: 24, spreadRadius: 4)],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.2),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrbitNode extends StatelessWidget {
  const _OrbitNode({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: const Color(0xFF202A5C),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 12)],
        ),
        child: Icon(icon, color: color, size: 16),
      );
}
