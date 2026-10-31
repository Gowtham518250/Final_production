import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_client.dart';


/// Structured API error. FastAPI may place a string or an object in "detail".
class RetailMindBillingException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const RetailMindBillingException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  factory RetailMindBillingException.fromResponse(
    http.Response response, {
    required String fallback,
  }) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Keep the endpoint-specific fallback for non-JSON proxy responses.
    }

    final detail = body['detail'];
    final detailMap = detail is Map
        ? Map<String, dynamic>.from(detail)
        : const <String, dynamic>{};
    final rawCode = body['code'] ?? detailMap['code'];
    final rawMessage = detailMap['message'] ??
        detailMap['detail'] ??
        (detail is String ? detail : null) ??
        body['message'];
    final message = rawMessage?.toString().trim();

    return RetailMindBillingException(
      statusCode: response.statusCode,
      code: rawCode?.toString() ?? '',
      message: message == null || message.isEmpty ? fallback : message,
    );
  }

  @override
  String toString() => message;
}

/// Server-authoritative snapshot of the shop's daily AI allowance.
@immutable
class AiUsageSnapshot {
  final int limit;
  final int used;
  final int remaining;
  final DateTime? resetsAt;
  final String? planCode;
  final String? planName;
  final String? subscriptionStatus;

  const AiUsageSnapshot({required this.limit, required this.used, required this.remaining, this.resetsAt, this.planCode, this.planName, this.subscriptionStatus});

  factory AiUsageSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['usage'] is Map ? Map<String, dynamic>.from(json['usage'] as Map) : json;
    final limit = _asInt(raw['daily_limit'] ?? raw['limit'], 0);
    final used = _asInt(raw['used'] ?? raw['queries_used'], 0);
    final remaining = _asInt(raw['remaining'] ?? raw['queries_remaining'], (limit - used).clamp(0, limit));
    final resetRaw = raw['resets_at'] ?? raw['reset_at'] ?? raw['period_end'];
    return AiUsageSnapshot(limit: limit, used: used, remaining: remaining < 0 ? 0 : (remaining > limit ? limit : remaining), resetsAt: resetRaw == null ? null : DateTime.tryParse(resetRaw.toString()), planCode: json['plan_code']?.toString() ?? raw['plan_code']?.toString(), planName: json['plan_name']?.toString() ?? raw['plan_name']?.toString(), subscriptionStatus: json['subscription_status']?.toString() ?? raw['subscription_status']?.toString());
  }

  static int _asInt(dynamic value, int fallback) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Dynamic plan definition supplied by the billing API.
@immutable
class RetailMindSubscriptionPlan {
  final String code;
  final String name;
  final int amountPaise;
  final int monthlyAmountPaise;
  final int yearlyAmountPaise;
  final String currency;
  final String interval;
  final int dailyAiQueryLimit;
  final List<String> features;
  final bool recommended;

  const RetailMindSubscriptionPlan({required this.code, required this.name, required this.amountPaise, this.monthlyAmountPaise = 0, this.yearlyAmountPaise = 0, required this.currency, required this.interval, required this.dailyAiQueryLimit, this.features = const [], this.recommended = false});
  double get amount => amountPaise / 100;
  double amountFor(String interval) => (interval == 'YEARLY' ? yearlyAmountPaise : monthlyAmountPaise) / 100;

  factory RetailMindSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount_paise'] ?? json['amount_minor'] ?? json['amount'] ?? json['price'];
    final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw?.toString() ?? '') ?? 0;
    final minor = json['amount_paise'] != null || json['amount_minor'] != null || json['amount_in_minor_units'] == true;
    final features = json['features'];
    final monthlyRaw = json['monthly_amount_paise'] ?? 0;
    final yearlyRaw = json['yearly_amount_paise'] ?? 0;
    final monthly = monthlyRaw is num ? monthlyRaw.round() : int.tryParse(monthlyRaw.toString()) ?? 0;
    final yearly = yearlyRaw is num ? yearlyRaw.round() : int.tryParse(yearlyRaw.toString()) ?? 0;
    return RetailMindSubscriptionPlan(code: (json['plan_code'] ?? json['code'] ?? json['id'] ?? '').toString(), name: (json['name'] ?? json['display_name'] ?? 'Retail Mind Plan').toString(), amountPaise: monthly > 0 ? monthly : (minor ? amount.round() : (amount * 100).round()), monthlyAmountPaise: monthly, yearlyAmountPaise: yearly, currency: (json['currency'] ?? 'INR').toString(), interval: (json['billing_interval'] ?? json['interval'] ?? 'month').toString(), dailyAiQueryLimit: _asInt(json['daily_ai_query_limit'] ?? json['ai_queries_per_day'] ?? json['daily_query_limit'], 0), features: features is List ? features.map((value) => value.toString()).toList() : const [], recommended: json['recommended'] == true || json['is_popular'] == true);
  }

  static int _asInt(dynamic value, int fallback) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Cashfree secrets and payment state never enter the Flutter client.
class RetailMindBillingService {
  static const plansPath = '/api/billing/plans';
  static const currentPath = '/api/billing/subscriptions/current';
  static const usagePath = '/api/billing/usage';
  static const createSubscriptionPath = '/api/billing/subscriptions';
  static const featureAccessSnapshotPath = '/api/billing/feature-access';
  static const Duration featureAccessCacheTtl = Duration(minutes: 3);

  static final Map<int, _FeatureAccessSnapshotCache> _featureAccessCache = {};
  static final Map<int, Future<Map<String, bool>>> _featureAccessInFlight = {};

  static String featureAccessPath(String featureCode) =>
      '/api/billing/feature-access/${Uri.encodeComponent(featureCode)}';

  static Future<int?> _currentOwnerId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get('user_id') ?? prefs.get('userId');
    final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    return id != null && id > 0 ? id : null;
  }

  /// Fetch all feature decisions with one server query and reuse them briefly
  /// while the owner moves between gated screens. The backend remains the
  /// authority for every protected operation.
  static Future<Map<String, bool>> fetchFeatureAccessSnapshot({
    bool forceRefresh = false,
  }) async {
    final ownerId = await _currentOwnerId();
    if (ownerId == null) {
      return _requestFeatureAccessSnapshot();
    }

    final cached = _featureAccessCache[ownerId];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < featureAccessCacheTtl) {
      return Map<String, bool>.unmodifiable(cached.features);
    }

    if (forceRefresh) _featureAccessCache.remove(ownerId);

    final existing = _featureAccessInFlight[ownerId];
    if (existing != null) return existing;

    final request = _requestFeatureAccessSnapshot();
    _featureAccessInFlight[ownerId] = request;
    try {
      final features = await request;
      if (features.isNotEmpty) {
        _featureAccessCache[ownerId] = _FeatureAccessSnapshotCache(
          features: Map<String, bool>.unmodifiable(features),
          fetchedAt: DateTime.now(),
        );
      }
      return features;
    } finally {
      if (identical(_featureAccessInFlight[ownerId], request)) {
        _featureAccessInFlight.remove(ownerId);
      }
    }
  }

  static Future<Map<String, bool>> _requestFeatureAccessSnapshot() async {
    final response = await ApiClient.getJson(featureAccessSnapshotPath)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return const {};
    if (response.statusCode != 200) {
      throw RetailMindBillingException.fromResponse(
        response,
        fallback: 'Unable to verify plan access (${response.statusCode}).',
      );
    }

    final body = _decode(response);
    final rawFeatures = body['features'];
    if (rawFeatures is! Map) {
      throw const FormatException(
        'The billing service returned an invalid feature-access response.',
      );
    }

    final features = <String, bool>{
      for (final entry in rawFeatures.entries)
        entry.key.toString(): entry.value == true,
    };
    final rawLimit = body['daily_ai_query_limit'];
    final dailyAiLimit = rawLimit is num
        ? rawLimit.toInt()
        : int.tryParse(rawLimit?.toString() ?? '') ?? 0;
    features['ai_queries'] = dailyAiLimit > 0;
    features['online_orders'] = features['online_orders'] == true;
    return features;
  }

  static Future<void> prefetchCommonFeatureAccess() async {
    try {
      await fetchFeatureAccessSnapshot();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Feature entitlement prefetch deferred: $error');
      }
    }
  }

  static Future<void> invalidateFeatureAccessCache() async {
    final ownerId = await _currentOwnerId();
    if (ownerId != null) _featureAccessCache.remove(ownerId);
  }

  static Future<bool> checkFeatureAccess(
    String featureCode, {
    bool forceRefresh = false,
  }) async {
    final snapshot = await fetchFeatureAccessSnapshot(
      forceRefresh: forceRefresh,
    );
    final cachedDecision = snapshot[featureCode];
    if (cachedDecision != null) return cachedDecision;

    // Compatibility with a backend version that has only the single-feature
    // route during a rolling deployment.
    final response = await ApiClient.getJson(featureAccessPath(featureCode))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw RetailMindBillingException.fromResponse(
        response,
        fallback: 'Unable to verify plan access (${response.statusCode}).',
      );
    }
    final body = _decode(response);
    if (body['allowed'] is! bool) {
      throw const FormatException(
        'The billing service returned an invalid access response.',
      );
    }

    final allowed = body['allowed'] as bool;
    final ownerId = await _currentOwnerId();
    if (ownerId != null) {
      final existing = _featureAccessCache[ownerId];
      final features = <String, bool>{...?existing?.features};
      features[featureCode] = allowed;
      _featureAccessCache[ownerId] = _FeatureAccessSnapshotCache(
        features: Map<String, bool>.unmodifiable(features),
        fetchedAt: DateTime.now(),
      );
    }
    return allowed;
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final value = jsonDecode(response.body);
    if (value is! Map) throw const FormatException('Unexpected billing response.');
    return Map<String, dynamic>.from(value);
  }

  static Future<List<RetailMindSubscriptionPlan>> fetchPlans() async {
    final response = await ApiClient.getJson(plansPath).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw RetailMindBillingException.fromResponse(response, fallback: 'Unable to load subscription plans (${response.statusCode}).');
    final body = _decode(response);
    final raw = body['plans'] ?? body['items'] ?? body['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((row) => RetailMindSubscriptionPlan.fromJson(Map<String, dynamic>.from(row))).where((plan) => plan.code.isNotEmpty).toList();
  }

  static Future<AiUsageSnapshot> fetchUsage() async {
    final response = await ApiClient.getJson(usagePath).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw RetailMindBillingException.fromResponse(response, fallback: 'Unable to load AI usage (${response.statusCode}).');
    return AiUsageSnapshot.fromJson(_decode(response));
  }

  static Future<Map<String, dynamic>> fetchCurrentSubscription() async {
    final response = await ApiClient.getJson(currentPath).timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return const {};
    if (response.statusCode != 200) throw RetailMindBillingException.fromResponse(response, fallback: 'Unable to load subscription (${response.statusCode}).');
    return _decode(response);
  }

  static Future<void> cancelSubscription(int subscriptionId) async {
    final response = await ApiClient.postJson('/api/billing/subscriptions/$subscriptionId/cancel', const {}).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw RetailMindBillingException.fromResponse(
        response,
        fallback: 'Unable to cancel subscription (${response.statusCode}).',
      );
    }
  }

  static Future<Map<String, dynamic>> createSubscription(String planCode, {String billingInterval = 'MONTHLY'}) async {
    final response = await ApiClient.postJson(createSubscriptionPath, {'plan_code': planCode, 'billing_interval': billingInterval}).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw RetailMindBillingException.fromResponse(
        response,
        fallback: 'Unable to start subscription (${response.statusCode}).',
      );
    }
    return _decode(response);
  }



}


class _FeatureAccessSnapshotCache {
  const _FeatureAccessSnapshotCache({
    required this.features,
    required this.fetchedAt,
  });

  final Map<String, bool> features;
  final DateTime fetchedAt;
}
