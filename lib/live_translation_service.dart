import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, ValueListenable;
import 'package:shared_preferences/shared_preferences.dart';

import 'live_translation_web.dart'
    if (dart.library.io) 'live_translation_native.dart' as platform;
import 'device_capability_service.dart';
import 'dynamic_translation_load_policy.dart';

/// Translates dynamic display strings with a small bounded queue.
/// Duplicate strings are coalesced and requests are batched to avoid a remote
/// AI call for every widget on the page.
class LiveTranslationService {
  LiveTranslationService._();

  static final LiveTranslationService instance = LiveTranslationService._();

  static const int _standardMaxBatchItems = 20;
  static const int _standardMaxCachedTranslations = 1200;
  static const int _standardMaxCacheableTextCharacters = 800;
  static const int _standardMaxCachedTextCharacters = 256 * 1024;

  // Keep translation work and retained text much smaller on entry-level phones.
  int get _maxBatchItems =>
      DeviceCapabilityService.instance.isLowEndDevice ? 8 : _standardMaxBatchItems;
  int get _maxCachedTranslations =>
      DeviceCapabilityService.instance.isLowEndDevice ? 400 : _standardMaxCachedTranslations;
  int get _maxCacheableTextCharacters =>
      DeviceCapabilityService.instance.isLowEndDevice ? 480 : _standardMaxCacheableTextCharacters;
  int get _maxCachedTextCharacters =>
      DeviceCapabilityService.instance.isLowEndDevice ? 96 * 1024 : _standardMaxCachedTextCharacters;

  // Start conservatively and only allow two batches when device detection says
  // this is not a low-RAM/low-core device.
  int get _maxConcurrentBatches =>
      DeviceCapabilityService.instance.isLowEndDevice ? 1 : 2;
  Duration get _batchCoalesceDelay =>
      DeviceCapabilityService.instance.isLowEndDevice
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 25);

  final LinkedHashMap<String, String> _cache = LinkedHashMap<String, String>();
  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};
  final Queue<_TranslationTask> _queue = Queue<_TranslationTask>();
  int _activeBatches = 0;
  int _cachedTextCharacters = 0;
  bool _pumpScheduled = false;

  static const String _persistentCacheKey =
      'retail_mind_dynamic_translation_cache_v1';
  static const int _standardMaxDeferredUniqueRequests = 600;
  static const int _standardMaxRetryCooldownEntries = 240;
  int get _maxDeferredUniqueRequests =>
      DeviceCapabilityService.instance.isLowEndDevice ? 180 : _standardMaxDeferredUniqueRequests;
  int get _maxRetryCooldownEntries =>
      DeviceCapabilityService.instance.isLowEndDevice ? 120 : _standardMaxRetryCooldownEntries;
  static const Duration _translationRetryCooldown = Duration(seconds: 45);

  final Set<String> _deferred = <String>{};
  final LinkedHashMap<String, DateTime> _retryAfter =
      LinkedHashMap<String, DateTime>();
  final ValueNotifier<int> _capacityRevision = ValueNotifier<int>(0);
  Future<void>? _persistentCacheLoad;
  Timer? _persistCacheTimer;

  /// Widgets use this to retry strings that were deferred because the queue
  /// was full. It is not a broadcast of every translation result.
  ValueListenable<int> get capacityChanges => _capacityRevision;

  /// Whether this exact text is waiting because the low-memory queue was full.
  /// Widgets only subscribe to capacity changes while they have deferred work.
  bool hasDeferredTranslation(
    String text, {
    required String targetLanguageCode,
  }) {
    final key = '$targetLanguageCode\u0000${text.trim()}';
    return _deferred.contains(key);
  }

  bool isDeferredAndRetryable(
    String text, {
    required String targetLanguageCode,
  }) {
    final key = '$targetLanguageCode\u0000${text.trim()}';
    final hasDeferredRequest = _deferred.contains(key);
    final hasCachedResult = _cache.containsKey(key);
    if (!hasDeferredRequest && !hasCachedResult) return false;
    final lowEnd = DeviceCapabilityService.instance.isLowEndDevice;
    return hasCachedResult ||
        _inFlight.length < DynamicTranslationLoadPolicy.maxPending(
          lowEndDevice: lowEnd,
        );
  }

  Future<String> translateForDisplay(
    String text, {
    required String targetLanguageCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        targetLanguageCode == 'en' ||
        !_containsTranslatableLetters(trimmed, targetLanguageCode)) {
      return text;
    }

    // Disk I/O is only used for unmatched dynamic strings; curated/local UI
    // labels still resolve synchronously in LiveTranslatedText.
    await _ensurePersistentCacheLoaded();

    final key = '$targetLanguageCode\u0000$trimmed';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      _deferred.remove(key);
      return cached;
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final retryAfter = _retryAfter[key];
    if (retryAfter != null) {
      if (retryAfter.isAfter(DateTime.now())) {
        _deferred.remove(key);
        return text;
      }
      _retryAfter.remove(key);
    }

    if (!DynamicTranslationLoadPolicy.shouldAccept(
      pendingUniqueRequests: _inFlight.length,
      lowEndDevice: DeviceCapabilityService.instance.isLowEndDevice,
    )) {
      // Keep a small retry marker rather than an unbounded list of futures.
      // LiveTranslatedText retries these markers as capacity becomes available.
      if (!_deferred.contains(key)) {
        if (_deferred.length >= _maxDeferredUniqueRequests &&
            _deferred.isNotEmpty) {
          // Favor newly mounted/currently displayed text while keeping retry
          // bookkeeping bounded across repeated screen navigation.
          _deferred.remove(_deferred.first);
        }
        _deferred.add(key);
      }
      return text;
    }

    // Do not remove an existing deferred marker until the request successfully
    // lands in cache. Other widgets with the same text can then pick up the
    // cached value instead of remaining stuck on the original string.
    final completer = Completer<String>();
    _inFlight[key] = completer.future;
    _queue.add(
      _TranslationTask(
        key: key,
        text: trimmed,
        targetLanguageCode: targetLanguageCode,
        completer: completer,
      ),
    );
    _schedulePump();
    return completer.future;
  }

  Future<void> _ensurePersistentCacheLoaded() {
    return _persistentCacheLoad ??= _loadPersistentCache();
  }

  Future<void> _loadPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_persistentCacheKey);
      if (encoded == null || encoded.isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;

      for (final entry in decoded.entries) {
        if (entry.key is String && entry.value is String) {
          _storeCachedTranslation(
            entry.key as String,
            entry.value as String,
            persist: false,
          );
        }
      }
    } catch (_) {
      // Corrupt or unavailable cache must never stop the original text showing.
    }
  }

  void _scheduleCachePersistence() {
    _persistCacheTimer?.cancel();
    _persistCacheTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _persistentCacheKey,
          jsonEncode(_cache),
        );
      } catch (_) {
        // Dynamic translations remain in memory for this session.
      }
    });
  }

  void _markRetryCooldown(String key) {
    _retryAfter.remove(key);
    _retryAfter[key] = DateTime.now().add(_translationRetryCooldown);
    while (_retryAfter.length > _maxRetryCooldownEntries) {
      _retryAfter.remove(_retryAfter.keys.first);
    }
  }

  void _schedulePump() {
    if (_pumpScheduled) return;
    _pumpScheduled = true;
    Timer(_batchCoalesceDelay, () {
      _pumpScheduled = false;
      _pumpQueue();
    });
  }

  void _pumpQueue() {
    while (_activeBatches < _maxConcurrentBatches && _queue.isNotEmpty) {
      final first = _queue.removeFirst();
      final batch = <_TranslationTask>[first];
      for (final candidate in _queue.toList()) {
        if (batch.length >= _maxBatchItems) break;
        if (candidate.targetLanguageCode == first.targetLanguageCode) {
          _queue.remove(candidate);
          batch.add(candidate);
        }
      }
      _activeBatches++;
      unawaited(_translateBatch(batch));
    }
  }

  Future<void> _translateBatch(List<_TranslationTask> batch) async {
    try {
      final translated = await platform.translateTexts(
        batch.map((task) => task.text).toList(),
        batch.first.targetLanguageCode,
      );
      for (var index = 0; index < batch.length; index++) {
        final task = batch[index];
        final value = index < translated.length &&
                translated[index].trim().isNotEmpty
            ? translated[index]
            : task.text;
        // Avoid caching a transient offline/auth fallback forever. A later
        // screen rebuild can retry once the session or connection is restored.
        if (value.trim() != task.text.trim()) {
          _storeCachedTranslation(task.key, value);
        } else {
          // Avoid retrying unchanged/failed results every time queue capacity
          // changes during a poor connection or an unavailable language model.
          _markRetryCooldown(task.key);
        }
        if (!task.completer.isCompleted) task.completer.complete(value);
        _inFlight.remove(task.key);
      }
    } catch (_) {
      for (final task in batch) {
        _markRetryCooldown(task.key);
        if (!task.completer.isCompleted) task.completer.complete(task.text);
        _inFlight.remove(task.key);
      }
    } finally {
      _activeBatches--;

      // Mounted LiveTranslatedText widgets listen for deferred work. Do not
      // broadcast to every visible text widget after every ordinary batch:
      // that creates O(visible widgets × batches) callback work on low-RAM
      // devices. Retry a deferred wave only after the accepted queue drains.
      if (_deferred.isNotEmpty && _queue.isEmpty) {
        _capacityRevision.value = _capacityRevision.value + 1;
      }

      if (_queue.isNotEmpty) _schedulePump();
    }
  }

  void _storeCachedTranslation(
    String key,
    String value, {
    bool persist = true,
  }) {
    final existing = _cache.remove(key);
    if (existing != null) {
      _cachedTextCharacters -= key.length + existing.length;
    }

    final entryCharacters = key.length + value.length;
    // Avoid keeping large descriptions/notes in memory cache. They can still
    // be translated for display, but are not worth retaining on 2GB devices.
    if (entryCharacters > _maxCacheableTextCharacters) {
      _deferred.remove(key);
      _retryAfter.remove(key);
      return;
    }

    _cache[key] = value;
    _cachedTextCharacters += entryCharacters;
    _deferred.remove(key);
    _retryAfter.remove(key);
    while (_cache.isNotEmpty &&
        (_cache.length > _maxCachedTranslations ||
            _cachedTextCharacters > _maxCachedTextCharacters)) {
      final oldestKey = _cache.keys.first;
      final oldestValue = _cache.remove(oldestKey)!;
      _cachedTextCharacters -= oldestKey.length + oldestValue.length;
    }
    if (persist) _scheduleCachePersistence();
  }

  static final RegExp _latinLetterPattern =
      RegExp(r'[A-Za-z\u00C0-\u024F]');
  static final RegExp _neverTargetScriptPattern = RegExp(r'(?!)');
  static final Map<String, RegExp> _targetScriptPatterns = {
    'te': RegExp(r'[\u0C00-\u0C7F]'),
    'hi': RegExp(r'[\u0900-\u097F]'),
    'mr': RegExp(r'[\u0900-\u097F]'),
    'ta': RegExp(r'[\u0B80-\u0BFF]'),
    'kn': RegExp(r'[\u0C80-\u0CFF]'),
    'ml': RegExp(r'[\u0D00-\u0D7F]'),
    'gu': RegExp(r'[\u0A80-\u0AFF]'),
    'pa': RegExp(r'[\u0A00-\u0A7F]'),
    'bn': RegExp(r'[\u0980-\u09FF]'),
  };

  bool _containsTranslatableLetters(String value, String targetCode) {
    if (_latinLetterPattern.hasMatch(value)) return true;
    return !_hasTargetScript(value, targetCode);
  }

  bool _hasTargetScript(String value, String targetCode) {
    return (_targetScriptPatterns[targetCode] ?? _neverTargetScriptPattern)
        .hasMatch(value);
  }
}

class _TranslationTask {
  const _TranslationTask({
    required this.key,
    required this.text,
    required this.targetLanguageCode,
    required this.completer,
  });

  final String key;
  final String text;
  final String targetLanguageCode;
  final Completer<String> completer;
}
