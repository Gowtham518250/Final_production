import 'dart:async';

import 'package:flutter/material.dart';

import '../../live_translated_text.dart';
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

        final colors = Theme.of(context).colorScheme;
        final featureMessage = switch (widget.featureCode) {
          'online_orders' => 'Online orders are part of a paid plan',
          'ai_queries' => 'AI queries are part of a paid plan',
          'voice_billing' => 'Voice billing is part of a paid plan',
          _ => 'This feature is part of a paid plan',
        };

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: const LiveTranslatedText('Upgrade required'),
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.07),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 34,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: LiveTranslatedText(
                              'PAID PLAN FEATURE',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          LiveTranslatedText(
                            featureMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          LiveTranslatedText(
                            'Choose a plan that includes this feature to unlock it.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const RetailMindSubscriptionPage(),
                                  ),
                                );
                                if (mounted) await _retry();
                              },
                              icon: const Icon(
                                Icons.workspace_premium_outlined,
                              ),
                              label: const LiveTranslatedText(
                                'View plans and upgrade',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
