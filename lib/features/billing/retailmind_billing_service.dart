import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../api_client.dart';

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
    final limit = _asInt(raw['daily_limit'] ?? raw['limit'], 7);
    final used = _asInt(raw['used'] ?? raw['queries_used'], 0);
    final remaining = _asInt(raw['remaining'] ?? raw['queries_remaining'], (limit - used).clamp(0, limit));
    final resetRaw = raw['resets_at'] ?? raw['reset_at'] ?? raw['period_end'];
    return AiUsageSnapshot(limit: limit, used: used, remaining: remaining.clamp(0, limit), resetsAt: resetRaw == null ? null : DateTime.tryParse(resetRaw.toString()), planCode: json['plan_code']?.toString() ?? raw['plan_code']?.toString(), planName: json['plan_name']?.toString() ?? raw['plan_name']?.toString(), subscriptionStatus: json['subscription_status']?.toString() ?? raw['subscription_status']?.toString());
  }

  static int _asInt(dynamic value, int fallback) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Dynamic plan definition supplied by the billing API.
@immutable
class RetailMindSubscriptionPlan {
  final String code;
  final String name;
  final int amountPaise;
  final String currency;
  final String interval;
  final int dailyAiQueryLimit;
  final List<String> features;
  final bool recommended;

  const RetailMindSubscriptionPlan({required this.code, required this.name, required this.amountPaise, required this.currency, required this.interval, required this.dailyAiQueryLimit, this.features = const [], this.recommended = false});
  double get amount => amountPaise / 100;

  factory RetailMindSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount_paise'] ?? json['amount_minor'] ?? json['amount'] ?? json['price'];
    final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw?.toString() ?? '') ?? 0;
    final minor = json['amount_paise'] != null || json['amount_minor'] != null || json['amount_in_minor_units'] == true;
    final features = json['features'];
    return RetailMindSubscriptionPlan(code: (json['plan_code'] ?? json['code'] ?? json['id'] ?? '').toString(), name: (json['name'] ?? json['display_name'] ?? 'Retail Mind Plan').toString(), amountPaise: minor ? amount.round() : (amount * 100).round(), currency: (json['currency'] ?? 'INR').toString(), interval: (json['billing_interval'] ?? json['interval'] ?? 'month').toString(), dailyAiQueryLimit: _asInt(json['daily_ai_query_limit'] ?? json['ai_queries_per_day'] ?? json['daily_query_limit'], 7), features: features is List ? features.map((value) => value.toString()).toList() : const [], recommended: json['recommended'] == true || json['is_popular'] == true);
  }

  static int _asInt(dynamic value, int fallback) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Cashfree secrets and payment state never enter the Flutter client.
class RetailMindBillingService {
  static const plansPath = '/api/billing/plans';
  static const currentPath = '/api/billing/subscriptions/current';
  static const usagePath = '/api/billing/usage';
  static const createSubscriptionPath = '/api/billing/subscriptions';

  static Map<String, dynamic> _decode(http.Response response) {
    final value = jsonDecode(response.body);
    if (value is! Map) throw const FormatException('Unexpected billing response.');
    return Map<String, dynamic>.from(value);
  }

  static Future<List<RetailMindSubscriptionPlan>> fetchPlans() async {
    final response = await ApiClient.getJson(plansPath).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Unable to load subscription plans (${response.statusCode}).');
    final body = _decode(response);
    final raw = body['plans'] ?? body['items'] ?? body['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((row) => RetailMindSubscriptionPlan.fromJson(Map<String, dynamic>.from(row))).where((plan) => plan.code.isNotEmpty).toList();
  }

  static Future<AiUsageSnapshot> fetchUsage() async {
    final response = await ApiClient.getJson(usagePath).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Unable to load AI usage (${response.statusCode}).');
    return AiUsageSnapshot.fromJson(_decode(response));
  }

  static Future<Map<String, dynamic>> fetchCurrentSubscription() async {
    final response = await ApiClient.getJson(currentPath).timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return const {};
    if (response.statusCode != 200) throw Exception('Unable to load subscription (${response.statusCode}).');
    return _decode(response);
  }

  static Future<Map<String, dynamic>> createSubscription(String planCode) async {
    final response = await ApiClient.postJson(createSubscriptionPath, {'plan_code': planCode}).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      var message = 'Unable to start subscription (${response.statusCode}).';
      try { final body = _decode(response); message = (body['detail'] ?? body['message'] ?? message).toString(); } catch (_) {}
      throw Exception(message);
    }
    return _decode(response);
  }
}
