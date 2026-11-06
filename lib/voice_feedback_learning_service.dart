import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// 🧠 ADVANCED: Voice Feedback Learning Service
/// Learns from user corrections to improve voice recognition accuracy over time
class VoiceFeedbackLearningService {
  static const String _feedbackKey = 'voice_billing_feedback';
  static const String _userCorrectionsKey = 'voice_user_corrections';
  static const String _accuracyMetricsKey = 'voice_accuracy_metrics';
  
  /// Record user correction for misinterpreted voice
  static Future<void> recordCorrection({
    required String originalTranscript,
    required String correctedItemName,
    required String languageCode,
    required double originalConfidence,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final corrections = prefs.getStringList(_userCorrectionsKey) ?? [];
      
      final correctionEntry = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'original_transcript': originalTranscript,
        'corrected_name': correctedItemName,
        'language': languageCode,
        'original_confidence': originalConfidence,
      });
      
      corrections.add(correctionEntry);
      
      // Keep only last 1000 corrections to prevent unbounded growth
      if (corrections.length > 1000) {
        corrections.removeRange(0, corrections.length - 1000);
      }
      
      await prefs.setStringList(_userCorrectionsKey, corrections);

      // Learn only from an explicit cashier correction. The backend resolves the
      // exact product name inside the authenticated shop, so device data cannot
      // create or activate aliases in another shop's catalog.
      try {
        final cleanOriginal = originalTranscript.trim();
        final cleanProductName = correctedItemName.trim();
        if (cleanOriginal.isNotEmpty &&
            cleanProductName.isNotEmpty &&
            cleanOriginal.toLowerCase() != cleanProductName.toLowerCase()) {
          final response = await ApiClient.postJson(
            ApiClient.voiceBillingAliasesEndpoint,
            {
              'alias_text': cleanOriginal,
              'product_name': cleanProductName,
              'language_code': languageCode,
            },
          );
          if (response.statusCode < 200 || response.statusCode >= 300) {
            if (kDebugMode) {
              debugPrint('Shop voice learning did not accept this correction (HTTP ${response.statusCode}).');
            }
          }
        }
      } catch (_) {
        // Local correction history remains available if the shop is offline.
        if (kDebugMode) debugPrint('Shop voice learning sync unavailable.');
      }

      if (kDebugMode) {
        debugPrint('Voice correction recorded for language $languageCode.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to record correction: $e');
    }
  }
  
  /// Get common misinterpretations for a language
  /// Returns Map<mispronouncedWord, correctWord>
  static Future<Map<String, String>> getCommonCorrections(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final corrections = prefs.getStringList(_userCorrectionsKey) ?? [];
      final phraseVotes = <String, Map<String, int>>{};

      for (final entry in corrections) {
        final data = json.decode(entry);
        if (data['language'] != languageCode) continue;
        final original = _normalizeLearningPhrase(
          (data['original_transcript'] ?? '').toString(),
        );
        final corrected = _normalizeLearningPhrase(
          (data['corrected_name'] ?? '').toString(),
        );
        if (original.isEmpty || corrected.isEmpty || original == corrected) continue;
        final votes = phraseVotes.putIfAbsent(original, () => <String, int>{});
        votes[corrected] = (votes[corrected] ?? 0) + 1;
      }

      final correctionMap = <String, String>{};
      phraseVotes.forEach((original, votes) {
        final ranked = votes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (ranked.isNotEmpty &&
            ranked.first.value >= 3 &&
            (ranked.length == 1 || ranked.first.value > ranked[1].value)) {
          correctionMap[original] = ranked.first.key;
        }
      });
      return correctionMap;
    } catch (e) {
      if (kDebugMode) debugPrint('Voice correction lookup failed: $e');
      return {};
    }
  }

  /// Record accuracy metrics
  static Future<void> recordAccuracyMetrics({
    required String languageCode,
    required bool usedCloudSTT,
    required double sttConfidence,
    required double nlpConfidence,
    required int itemsCorrect,
    required int itemsTotal,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_accuracyMetricsKey) ?? [];
      
      final metricEntry = json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'language': languageCode,
        'used_cloud_stt': usedCloudSTT,
        'stt_confidence': sttConfidence,
        'nlp_confidence': nlpConfidence,
        'items_correct': itemsCorrect,
        'items_total': itemsTotal,
        'accuracy': itemsTotal > 0 ? itemsCorrect / itemsTotal : 0.0,
      });
      
      metrics.add(metricEntry);
      
      // Keep only last 500 metrics
      if (metrics.length > 500) {
        metrics.removeRange(0, metrics.length - 500);
      }
      
      await prefs.setStringList(_accuracyMetricsKey, metrics);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to record metrics: $e');
    }
  }
  
  /// Get accuracy metrics for a language
  static Future<Map<String, dynamic>> getAccuracyMetrics(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = prefs.getStringList(_accuracyMetricsKey) ?? [];
      
      final languageMetrics = metrics.where((entry) {
        final data = json.decode(entry);
        return data['language'] == languageCode;
      }).toList();
      
      if (languageMetrics.isEmpty) {
        return {
          'total_records': 0,
          'avg_stt_confidence': 0.0,
          'avg_nlp_confidence': 0.0,
          'avg_accuracy': 0.0,
          'cloud_usage': 0.0,
        };
      }
      
      double totalSTTConfidence = 0.0;
      double totalNLPConfidence = 0.0;
      double totalAccuracy = 0.0;
      int cloudUsage = 0;
      
      for (final entry in languageMetrics) {
        final data = json.decode(entry);
        totalSTTConfidence += (data['stt_confidence'] as num).toDouble();
        totalNLPConfidence += (data['nlp_confidence'] as num).toDouble();
        totalAccuracy += (data['accuracy'] as num).toDouble();
        if (data['used_cloud_stt'] == true) cloudUsage++;
      }
      
      final count = languageMetrics.length;
      
      return {
        'total_records': count,
        'avg_stt_confidence': totalSTTConfidence / count,
        'avg_nlp_confidence': totalNLPConfidence / count,
        'avg_accuracy': totalAccuracy / count,
        'cloud_usage': cloudUsage / count,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get accuracy metrics: $e');
      return {};
    }
  }
  
  /// Clear all learning data (for testing/reset)
  static Future<void> clearLearningData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCorrectionsKey);
    await prefs.remove(_accuracyMetricsKey);
    
    if (kDebugMode) debugPrint('🗑️ Cleared voice learning data');
  }
  
  static String _normalizeLearningPhrase(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // Treat letters/digits in Latin and common Indic blocks as word characters.
  // This avoids ASCII-only word-boundary behavior for Indian-language aliases.
  static bool _isLearningWordCodeUnit(int unit) {
    return (unit >= 0x30 && unit <= 0x39) ||
        (unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        (unit >= 0x00C0 && unit <= 0x02AF) ||
        (unit >= 0x0300 && unit <= 0x036F) ||
        (unit >= 0x0900 && unit <= 0x0DFF) ||
        (unit >= 0x0E00 && unit <= 0x0EFF) ||
        (unit >= 0x1000 && unit <= 0x109F) ||
        unit == 0x200C ||
        unit == 0x200D ||
        unit == 0x5F;
  }

  static String _replaceWholeLearningPhrase(
    String source,
    String phrase,
    String replacement,
  ) {
    final needle = _normalizeLearningPhrase(phrase);
    if (needle.isEmpty) return source;

    final lowerSource = source.toLowerCase();
    final output = StringBuffer();
    var appendFrom = 0;
    var searchFrom = 0;

    while (searchFrom < lowerSource.length) {
      final found = lowerSource.indexOf(needle, searchFrom);
      if (found < 0) break;
      final end = found + needle.length;
      final leftBoundary = found == 0 ||
          !_isLearningWordCodeUnit(source.codeUnitAt(found - 1));
      final rightBoundary = end >= source.length ||
          !_isLearningWordCodeUnit(source.codeUnitAt(end));

      if (leftBoundary && rightBoundary && found >= appendFrom) {
        output.write(source.substring(appendFrom, found));
        output.write(replacement);
        appendFrom = end;
      }
      searchFrom = end;
    }

    if (appendFrom == 0) return source;
    output.write(source.substring(appendFrom));
    return output.toString();
  }

  /// Apply learned corrections using literal, Unicode-aware phrase boundaries.
  /// Longest aliases run first so a short alias cannot consume a longer phrase.
  static Future<String> applyLearnedCorrections({
    required String transcript,
    required String languageCode,
  }) async {
    try {
      final corrections = await getCommonCorrections(languageCode);
      if (corrections.isEmpty) return transcript;

      var corrected = transcript.toLowerCase();
      final entries = corrections.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));
      for (final entry in entries) {
        corrected = _replaceWholeLearningPhrase(
          corrected,
          entry.key,
          entry.value,
        );
      }
      return corrected;
    } catch (e) {
      if (kDebugMode) debugPrint('Voice correction matching failed: $e');
      return transcript;
    }
  }

  /// Get learning statistics
  static Future<Map<String, dynamic>> getLearningStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final corrections = prefs.getStringList(_userCorrectionsKey) ?? [];
      final metrics = prefs.getStringList(_accuracyMetricsKey) ?? [];
      
      // Count corrections by language
      final Map<String, int> correctionsByLang = {};
      for (final entry in corrections) {
        final data = json.decode(entry);
        final lang = data['language'] as String? ?? 'unknown';
        correctionsByLang[lang] = (correctionsByLang[lang] ?? 0) + 1;
      }
      
      // Count metrics by language
      final Map<String, int> metricsByLang = {};
      for (final entry in metrics) {
        final data = json.decode(entry);
        final lang = data['language'] as String? ?? 'unknown';
        metricsByLang[lang] = (metricsByLang[lang] ?? 0) + 1;
      }
      
      return {
        'total_corrections': corrections.length,
        'total_metrics': metrics.length,
        'corrections_by_language': correctionsByLang,
        'metrics_by_language': metricsByLang,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to get learning statistics: $e');
      return {};
    }
  }
}
