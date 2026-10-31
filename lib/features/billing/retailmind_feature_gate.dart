import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../api_client.dart';
import 'retailmind_subscription_page.dart';

class RetailMindFeatureAccess {
  static Future<bool> allows(String featureCode) async {
    final response = await ApiClient.getJson('/api/billing/feature-access/${Uri.encodeComponent(featureCode)}').timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Unable to verify subscription access.');
    final data = jsonDecode(response.body);
    return data is Map && data['allowed'] == true;
  }
}

class RetailMindFeatureGate extends StatelessWidget {
  final String featureCode;
  final Widget child;
  const RetailMindFeatureGate({super.key, required this.featureCode, required this.child});

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: RetailMindFeatureAccess.allows(featureCode),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.hasError) return const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Could not verify your plan. Check your connection and retry.', textAlign: TextAlign.center))));
      if (snapshot.data == true) return child;
      return Scaffold(
        appBar: AppBar(title: const Text('Upgrade required')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 56),
          const SizedBox(height: 16),
          Text('${featureCode.split('_').join(' ')} requires a paid plan', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Choose a plan that includes this feature to unlock it.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RetailMindSubscriptionPage())), icon: const Icon(Icons.workspace_premium_outlined), label: const Text('View plans and upgrade')),
        ]))),
      );
    },
  );
}