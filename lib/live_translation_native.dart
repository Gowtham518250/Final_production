import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'live_translation_remote.dart';
import 'translation_fallback_policy.dart';
import 'device_capability_service.dart';

final OnDeviceTranslatorModelManager _modelManager =
    OnDeviceTranslatorModelManager();

// Single-flight maps prevent duplicate downloads and translator instances.
final Map<String, Future<void>> _modelDownloads = <String, Future<void>>{};
final Map<String, Future<OnDeviceTranslator>> _translatorTasks =
    <String, Future<OnDeviceTranslator>>{};

TranslateLanguage? _targetFor(String code) {
  switch (code) {
    case 'en':
      return TranslateLanguage.english;
    case 'te':
      return TranslateLanguage.telugu;
    case 'hi':
      return TranslateLanguage.hindi;
    case 'ta':
      return TranslateLanguage.tamil;
    case 'kn':
      return TranslateLanguage.kannada;
    case 'mr':
      return TranslateLanguage.marathi;
    case 'gu':
      return TranslateLanguage.gujarati;
    case 'bn':
      return TranslateLanguage.bengali;
    default:
      // Malayalam and Punjabi aren't exposed by the plugin version pinned in
      // this app, so use the authenticated backend batch route for those locales.
      return null;
  }
}

Future<void> _ensureModelDownloaded(String languageCode) async {
  final existing = _modelDownloads[languageCode];
  if (existing != null) {
    await existing;
    return;
  }

  final task = () async {
    if (!await _modelManager.isModelDownloaded(languageCode)) {
      await _modelManager.downloadModel(languageCode);
    }
  }();
  _modelDownloads[languageCode] = task;

  try {
    await task;
  } catch (_) {
    if (identical(_modelDownloads[languageCode], task)) {
      _modelDownloads.remove(languageCode);
    }
    rethrow;
  }
}

Future<OnDeviceTranslator> _translatorFor(
  String targetLanguageCode,
  TranslateLanguage target,
) async {
  final existing = _translatorTasks[targetLanguageCode];
  if (existing != null) {
    try {
      return await existing;
    } catch (_) {
      if (identical(_translatorTasks[targetLanguageCode], existing)) {
        _translatorTasks.remove(targetLanguageCode);
      }
      rethrow;
    }
  }

  final englishCode = TranslateLanguage.english.bcpCode;
  final targetCode = target.bcpCode;
  final task = () async {
    // Sequential downloads avoid two model-download jobs competing for CPU,
    // network and memory during the first translated screen on entry devices.
    await _ensureModelDownloaded(englishCode);
    await _ensureModelDownloaded(targetCode);
    return OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: target,
    );
  }();
  _translatorTasks[targetLanguageCode] = task;

  try {
    return await task;
  } catch (_) {
    if (identical(_translatorTasks[targetLanguageCode], task)) {
      _translatorTasks.remove(targetLanguageCode);
    }
    rethrow;
  }
}

Future<List<String>> translateTexts(
  List<String> texts,
  String targetLanguageCode,
) async {
  if (texts.isEmpty || targetLanguageCode == 'en') return texts;

  final target = _targetFor(targetLanguageCode);
  final result = List<String>.of(texts);
  final localIndexes = <int>[];
  final remoteIndexes = <int>[];

  // On low-RAM devices, prefer the server's batched IndicTrans2 translation
  // while online. This avoids loading English + target-language ML Kit models
  // into the app process just to translate a screen full of dynamic labels.
  // If the device is offline, keep the existing on-device path for languages
  // supported by ML Kit, preserving offline voice-billing/shop workflows.
  if (DeviceCapabilityService.instance.isLowEndDevice && target != null) {
    var online = false;
    try {
      online =
          await Connectivity().checkConnectivity() != ConnectivityResult.none;
    } catch (_) {
      // Unknown connectivity uses local translation rather than assuming the
      // remote service is reachable.
    }
    if (online) {
      // Keep dynamic translation off the app's memory/CPU budget when online.
      // Low-RAM devices use the authenticated server batch path and never load
      // two ML Kit models into the app process during screen rendering.
      return translateTextBatchRemotely(
        texts,
        targetLanguageCode,
        timeout: const Duration(seconds: 8),
      );
    }
  }

  final targetScriptRegex = switch (targetLanguageCode) {
    'te' => RegExp(r'[\u0C00-\u0C7F]'),
    'hi' || 'mr' => RegExp(r'[\u0900-\u097F]'),
    'ta' => RegExp(r'[\u0B80-\u0BFF]'),
    'kn' => RegExp(r'[\u0C80-\u0CFF]'),
    'ml' => RegExp(r'[\u0D00-\u0D7F]'),
    'gu' => RegExp(r'[\u0A80-\u0AFF]'),
    'pa' => RegExp(r'[\u0A00-\u0A7F]'),
    'bn' => RegExp(r'[\u0980-\u09FF]'),
    _ => RegExp(r'(?!)'),
  };
  final anyIndicScript = RegExp(r'[\u0900-\u0DFF]');
  final latinLetters = RegExp(r'[A-Za-z\u00C0-\u024F]');

  for (var index = 0; index < texts.length; index++) {
    final text = texts[index];
    if (text.trim().isEmpty) continue;
    final hasLatin = latinLetters.hasMatch(text);
    final hasIndic = anyIndicScript.hasMatch(text);
    if (!hasLatin && targetScriptRegex.hasMatch(text)) {
      // Already in the target writing system: preserve its spelling exactly.
      continue;
    }
    if (target == null) {
      // Only languages not exposed by the installed ML Kit plugin use the
      // backend translation provider. Supported languages must not consume
      // the limited Groq quota for ordinary UI text.
      remoteIndexes.add(index);
    } else if (!hasLatin || hasIndic) {
      // ML Kit's on-device translator accepts English as its source language.
      // Preserve non-English/mixed-script data rather than uploading it to a
      // paid API. Already-target-script text was handled above.
      continue;
    } else {
      localIndexes.add(index);
    }
  }

  if (target != null && localIndexes.isNotEmpty) {
    OnDeviceTranslator? translator;
    try {
      translator = await _translatorFor(
        targetLanguageCode,
        target,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // The first model initialization can take a while. Keep the UI flow
      // responsive and move these strings to the authenticated batch fallback.
      remoteIndexes.addAll(localIndexes);
    }

    if (translator != null) {
      final chunkSize =
          DeviceCapabilityService.instance.isLowEndDevice ? 2 : 4;
      for (var offset = 0; offset < localIndexes.length; offset += chunkSize) {
        final chunkIndexes = localIndexes
            .skip(offset)
            .take(chunkSize)
            .toList(growable: false);
        try {
          final translated = await Future.wait(
            chunkIndexes.map(
              (index) => translator!.translateText(texts[index]),
            ),
          );
          for (var index = 0; index < chunkIndexes.length; index++) {
            final sourceIndex = chunkIndexes[index];
            final translatedText = translated[index];
            if (TranslationFallbackPolicy.needsRemoteFallback(
              texts[sourceIndex],
              translatedText,
            )) {
              // Retry proper nouns that the local model passes through.
              remoteIndexes.add(sourceIndex);
            } else {
              result[sourceIndex] = translatedText;
            }
          }
        } catch (_) {
          // Only retry this small failed group; don't discard translations
          // that already succeeded in earlier chunks.
          remoteIndexes.addAll(chunkIndexes);
        }
      }
    }
  }

  if (remoteIndexes.isNotEmpty) {
    final uniqueRemoteIndexes = remoteIndexes.toSet().toList(growable: false);
    final remoteTexts =
        uniqueRemoteIndexes.map((index) => texts[index]).toList();
    final translated = await translateTextBatchRemotely(
      remoteTexts,
      targetLanguageCode,
      // Supported locales only use the remote route when the on-device model
      // is unavailable/unhelpful, so keep that recovery bounded. Unsupported
      // locales retain the remote provider's normal timeout.
      timeout: target == null
          ? const Duration(seconds: 30)
          : const Duration(seconds: 12),
    );
    for (var index = 0; index < uniqueRemoteIndexes.length; index++) {
      final sourceIndex = uniqueRemoteIndexes[index];
      final translatedText = translated[index];
      if (!TranslationFallbackPolicy.needsRemoteFallback(
        texts[sourceIndex],
        translatedText,
      )) {
        result[sourceIndex] = translatedText;
      }
    }
  }
  return result;
}
