import 'dart:async';

import 'package:flutter/material.dart';

import 'retailmind_billing_service.dart';
import 'retailmind_subscription_page.dart';

class RetailMindFeatureAccess {
  static Future<bool> allows(String featureCode) =>
      RetailMindBillingService.checkFeatureAccess(featureCode);
}

class RetailMindFeatureGate extends StatefulWidget {
  final String featureCode;
  final Widget child;

  const RetailMindFeatureGate({
    super.key,
    required this.featureCode,
    required this.child,
  });

  @override
  State<RetailMindFeatureGate> createState() => _RetailMindFeatureGateState();
}

class _RetailMindFeatureGateState extends State<RetailMindFeatureGate> {
  late Future<bool> _accessFuture;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  void _loadAccess() {
    _accessFuture = RetailMindFeatureAccess.allows(widget.featureCode);
  }

  Future<void> _retry() async {
    await RetailMindBillingService.invalidateFeatureAccessCache();
    if (!mounted) return;
    setState(_loadAccess);
  }

  String _errorMessage(Object error) {
    if (error is RetailMindBillingException) {
      switch (error.statusCode) {
        case 401:
          return 'Your session could not be verified. Please sign in again and retry.';
        case 403:
          return 'The server denied access to this account. Confirm that you are signed in as the shop owner.';
        case 404:
          return 'The deployed backend does not have the plan-verification endpoint yet. Update the backend service and retry.';
        case 503:
          return 'The billing service is temporarily unavailable. Check the backend service and retry.';
        default:
          return error.message;
      }
    }
    if (error is TimeoutException) {
      return 'The server did not respond in time. Check your internet connection and retry.';
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty || message == 'null') {
      return 'We could not contact the billing service. Check your connection and retry.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Verify plan access')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 52,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not verify your plan',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry verification'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.data == true) return widget.child;

        return Scaffold(
          appBar: AppBar(title: const Text('Upgrade required')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.featureCode.split('_').join(' ')} requires a paid plan',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a plan that includes this feature to unlock it.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RetailMindSubscriptionPage(),
                      ),
                    ),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: const Text('View plans and upgrade'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
