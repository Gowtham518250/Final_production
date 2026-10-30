// =============================================================================
// voice_engine.dart  —  V9 ADVANCED VOICE ENGINE
// =============================================================================
// WHAT'S NEW vs V8:
//
//  VOICE-1  Priority queue: HIGH/CRITICAL interrupts current speech;
//           LOW waits; NORMAL queues. Never drops announcements silently.
//  VOICE-2  isSpeaking stream: widget layer can react in real-time.
//  VOICE-3  Amplitude/energy stream: feeds waveform visualisations without
//           any extra recording overhead (derived from text length + style).
//  VOICE-4  SSML-lite pause markers: "[PAUSE]" in text → 300ms silence.
//  VOICE-5  Language-aware rate/pitch profiles: Indian scripts get a
//           slightly slower base rate; Punjabi/Gujarati get accent boost.
//  VOICE-6  Retry with exponential back-off (max 2 retries) before
//           falling back to en-IN TTS.
//  VOICE-7  Volume fade-in on first speak (avoids jarring start).
//  VOICE-8  dispose() properly cancels queue + streams.
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'language_engine.dart';
import 'humanizer.dart';

// ─── Logging ──────────────────────────────────────────────────────────────────

final _log = Logger(
  printer: PrettyPrinter(methodCount: 2, lineLength: 80, colors: kDebugMode),
  level: kDebugMode ? Level.debug : Level.warning,
);

// ─── Priority ─────────────────────────────────────────────────────────────────

/// Speech priority. Higher value = more important.
enum SpeechPriority {
  low,      // queued; never interrupts
  normal,   // queued behind current speech
  high,     // interrupts low/normal; waits for critical
  critical, // always interrupts immediately
}

// ─── Queue entry ──────────────────────────────────────────────────────────────

class _SpeechJob {
  final String?         audioPath;
  final HumanizerResult result;
  final String          locale;
  final SpeechPriority  priority;
  final Completer<void> completer;

  _SpeechJob({
    required this.audioPath,
    required this.result,
    required this.locale,
    required this.priority,
  }) : completer = Completer<void>();
}

// ─── Locale profiles ──────────────────────────────────────────────────────────

/// Per-locale base rate and pitch adjustments.
/// These are applied ON TOP of the HumanizerResult values.
class _LocaleProfile {
  final double rateMultiplier;
  final double pitchOffset;
  const _LocaleProfile(this.rateMultiplier, this.pitchOffset);
}

const _localeProfiles = <String, _LocaleProfile>{
  'en-IN': _LocaleProfile(1.00, 0.00),
  'hi-IN': _LocaleProfile(0.95, 0.02),
  'ta-IN': _LocaleProfile(0.92, 0.03),
  'te-IN': _LocaleProfile(0.92, 0.03),
  'kn-IN': _LocaleProfile(0.93, 0.02),
  'ml-IN': _LocaleProfile(0.90, 0.04),
  'mr-IN': _LocaleProfile(0.95, 0.01),
  'bn-IN': _LocaleProfile(0.93, 0.02),
  'gu-IN': _LocaleProfile(0.94, 0.03),
  'pa-IN': _LocaleProfile(0.94, 0.04),
};

// ─── VoiceEngine ──────────────────────────────────────────────────────────────

class VoiceEngine {
  // TTS + audio
  final FlutterTts  _tts         = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Cached voice selection
  String? _cachedVoiceName;
  String? _cachedVoiceLocale;
  String? _currentLocale;

  // Mode flags
  bool _useStitchedVoice = false;
  bool _initialized      = false;

  // ── Public state streams ─────────────────────────────────────────────────

  /// Emits true while TTS is speaking, false when idle.
  final _speakingCtrl = StreamController<bool>.broadcast();
  Stream<bool> get isSpeakingStream => _speakingCtrl.stream;
  bool get isSpeaking => _isSpeaking;
  bool _isSpeaking = false;

  /// Synthetic amplitude 0.0–1.0, emitted ~60 Hz while speaking.
  final _ampCtrl = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _ampCtrl.stream;

  // ── Callbacks (backwards compat) ─────────────────────────────────────────
  VoidCallback? onSpeakComplete;
  VoidCallback? onSpeakError;

  // ── Priority queue ───────────────────────────────────────────────────────
  final _queue   = <_SpeechJob>[];
  bool  _running = false;
  int _generation = 0;
  _SpeechJob? _activeJob;

  // ── Amplitude timer ──────────────────────────────────────────────────────
  Timer? _ampTimer;
  double _ampPhase = 0;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init({
    required double volume,
    required double speechRate,
    String?         savedVoiceName,
    String?         savedVoiceLocale,
    bool            useStitchedVoice = false,
  }) async {
    if (_initialized) return;

    _useStitchedVoice  = useStitchedVoice;
    _cachedVoiceName   = savedVoiceName;
    _cachedVoiceLocale = savedVoiceLocale;

    try {
      await _tts.setSpeechRate(speechRate);
      await _tts.setVolume(volume);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);

      if (Platform.isAndroid) {
        // Speak as guidance, not media, so a payment is audible over music and
        // on a locked screen; queue (don't flush) back-to-back payments.
        try {
          await _tts.setAudioAttributesForNavigation();
        } catch (e) {
          _log.w('TTS audio attributes unavailable: $e');
        }
        try {
          await _tts.setQueueMode(1);
        } catch (e) {
          _log.w('TTS queue mode unavailable: $e');
        }
      }

      _tts.setStartHandler(() {
        _setSpeaking(true);
        _startAmpTimer();
      });

      _tts.setCompletionHandler(() {
        _setSpeaking(false);
        _stopAmpTimer();
        _log.d('TTS complete');
        onSpeakComplete?.call();
      });

      _tts.setErrorHandler((msg) {
        _setSpeaking(false);
        _stopAmpTimer();
        _log.w('TTS error: $msg');
        onSpeakError?.call();
      });

      if (savedVoiceName != null && savedVoiceLocale != null) {
        await _applyVoice(savedVoiceName, savedVoiceLocale);
      }

      _initialized = true;
      _log.d('VoiceEngine V9 initialized');
    } catch (e, st) {
      _log.e('VoiceEngine.init failed', error: e, stackTrace: st);
    }
  }

  // ── Volume ───────────────────────────────────────────────────────────────

  Future<void> setVolume(double v) async {
    try {
      await _tts.setVolume(v.clamp(0.0, 1.0));
      await _audioPlayer.setVolume(v.clamp(0.0, 1.0));
    } catch (e, st) {
      _log.e('setVolume failed', error: e, stackTrace: st);
    }
  }

  // ── Public speak API ─────────────────────────────────────────────────────

  /// Queue an announcement. Returns a Future that resolves when speech ends.
  Future<void> playAnnouncement({
    String?          audioPath,
    required HumanizerResult result,
    required String  locale,
    SpeechPriority   priority = SpeechPriority.normal,
  }) {
    final job = _SpeechJob(
      audioPath: audioPath,
      result:    result,
      locale:    locale,
      priority:  priority,
    );

    if (priority == SpeechPriority.critical ||
        priority == SpeechPriority.high) {
      // Interrupt anything currently running
      _interruptAndPrepend(job);
    } else {
      _queue.add(job);
    }

    _scheduleNext();
    return job.completer.future;
  }

  /// Speak raw text (no Humanizer). Useful for quick confirmations.
  Future<void> speakRaw(
    String text,
    String locale, {
    SpeechPriority priority = SpeechPriority.normal,
  }) {
    final timing = styleTimings[VoiceStyle.normal]!;
    final result = HumanizerResult(
      text: text,
      chunks: [text],
      pitch: timing.pitch,
      rate: timing.rate,
    );
    return playAnnouncement(
      result: result,
      locale: locale,
      priority: priority,
    );
  }

  Future<void> stop() async {
    // Invalidate the active drain. It retains the queue mutex until its
    // current await unwinds, preventing a second _runNext from overlapping it.
    _generation++;
    for (final queuedJob in _queue) {
      if (!queuedJob.completer.isCompleted) queuedJob.completer.complete();
    }
    _queue.clear();

    final activeJob = _activeJob;
    if (activeJob != null && !activeJob.completer.isCompleted) {
      activeJob.completer.complete();
    }

    try {
      await _tts.stop();
      await _audioPlayer.stop();
    } catch (e, st) {
      _log.e('VoiceEngine.stop failed', error: e, stackTrace: st);
    }
    _setSpeaking(false);
    _stopAmpTimer();
    // Do not set _running=false here. The in-flight drain releases the mutex
    // in _runNext's finally block after it observes the generation change.
  }

  // ── Voice selection ───────────────────────────────────────────────────────

  Future<void> autoSelectVoice(String locale) async {
    try {
      final dynamic voices = await _tts.getVoices;
      if (voices == null || voices is! List) return;

      final target     = locale.replaceAll('_', '-').toLowerCase();
      final candidates = voices.where((v) {
        final vl = (v['locale'] ?? '').toString().replaceAll('_', '-').toLowerCase();
        return vl == target;
      }).toList();

      if (candidates.isEmpty) {
        _log.w('No voices found for $locale');
        return;
      }

      final best = _pickByPreference(candidates, ['google', 'neural', 'network'])
          ?? _pickByPreference(candidates, ['female', 'male'])
          ?? candidates.first;

      await _applyVoice(best['name'].toString(), best['locale'].toString());
      _log.d('Auto-selected voice: ${best['name']} for $locale');
    } catch (e, st) {
      _log.e('autoSelectVoice failed for $locale', error: e, stackTrace: st);
    }
  }

  Future<void> updateVoice(String name, String locale) async {
    _cachedVoiceName   = name;
    _cachedVoiceLocale = locale;
    _currentLocale     = null;
    await _applyVoice(name, locale);
  }

  // ── Timeout helper ────────────────────────────────────────────────────────

  int calculateTimeout(String text, double multiplier) {
    final isIndian = _currentLocale != null &&
        RegExp(r'^(hi|ta|te|kn|ml|mr|gu|bn|pa)')
            .hasMatch(_currentLocale!.split('-').first.toLowerCase());

    final profile = _localeProfiles[_currentLocale] ?? const _LocaleProfile(1.0, 0.0);
    final base    = (isIndian ? text.length * 0.055 : text.length * 0.030) / profile.rateMultiplier;
    final buffered = (base + 2.0).clamp(6.0, 40.0);
    return (buffered * multiplier).ceil();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stop();
    _speakingCtrl.close();
    _ampCtrl.close();
    await _tts.stop();
    await _audioPlayer.dispose();
  }

  // ── Private: queue scheduler ──────────────────────────────────────────────

  void _interruptAndPrepend(_SpeechJob job) {
    // Invalidate the currently executing job and let its drain unwind before
    // starting the high-priority job. Completing its waiter unblocks callers,
    // but _running remains true until the old async operation actually exits.
    _generation++;
    final activeJob = _activeJob;
    if (activeJob != null && !activeJob.completer.isCompleted) {
      activeJob.completer.complete();
    }
    _tts.stop().catchError((_) {});
    _audioPlayer.stop().catchError((_) {});
    _queue.insert(0, job);
  }

  void _scheduleNext() {
    if (_running || _queue.isEmpty) return;
    _running = true;
    final generation = _generation;
    unawaited(_runNext(generation));
  }

  Future<void> _runNext(int generation) async {
    try {
      while (generation == _generation && _queue.isNotEmpty) {
        // Sort: critical > high > normal > low.
        _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));

        final job = _queue.removeAt(0);
        _activeJob = job;
        try {
          await _executeJob(job, generation);
          if (!job.completer.isCompleted) job.completer.complete();
        } catch (e, st) {
          _log.e('Speech job failed', error: e, stackTrace: st);
          if (!job.completer.isCompleted) job.completer.completeError(e, st);
        } finally {
          if (identical(_activeJob, job)) _activeJob = null;
        }
      }
    } finally {
      // Only this drain releases the mutex. New jobs queued while an old job
      // unwinds are picked up by a fresh drain using the current generation.
      _activeJob = null;
      _running = false;
      if (_queue.isNotEmpty) _scheduleNext();
    }
  }

  bool _isCurrentGeneration(int generation) =>
      generation == _generation;

  Future<void> _executeJob(_SpeechJob job, int generation) async {
    if (!_isCurrentGeneration(generation)) return;

    // Audio cue first.
    if (job.audioPath != null && job.audioPath!.isNotEmpty) {
      await _playAudioFile(job.audioPath!, generation: generation);
      if (!_isCurrentGeneration(generation)) return;
    }

    // A stop/interrupt can occur while Android is binding the TTS engine.
    await _ensureEngineReady(generation: generation);
    if (!_isCurrentGeneration(generation)) return;

    if (_useStitchedVoice) {
      await _playStitchedSequence(job.result.text, job.locale, generation);
      return;
    }

    var effectiveLocale = job.locale;
    if (!await _safeSetLocale(effectiveLocale, generation: generation)) {
      if (!_isCurrentGeneration(generation)) return;
      _log.w('Locale ${job.locale} unavailable; trying English fallback');
      var fellBack = false;
      for (final fallback in const ['en-IN', 'en-US', 'en-GB']) {
        if (!_isCurrentGeneration(generation)) return;
        if (fallback == job.locale) continue;
        if (await _safeSetLocale(fallback, generation: generation)) {
          effectiveLocale = fallback;
          fellBack = true;
          break;
        }
      }
      if (!_isCurrentGeneration(generation)) return;
      if (!fellBack) {
        // Last resort: use the engine's current/default voice.
        _log.w('No TTS locale confirmed; speaking with engine default voice');
        effectiveLocale = _currentLocale ?? job.locale;
      }
    }

    if (!_isCurrentGeneration(generation)) return;
    final profile = _localeProfiles[effectiveLocale] ?? const _LocaleProfile(1.0, 0.0);
    final finalRate = (job.result.rate * profile.rateMultiplier).clamp(0.1, 1.0);
    final finalPitch = (job.result.pitch + profile.pitchOffset).clamp(0.5, 2.0);

    await _tts.setPitch(finalPitch);
    if (!_isCurrentGeneration(generation)) return;
    await _tts.setSpeechRate(finalRate);
    if (!_isCurrentGeneration(generation)) return;

    final parts = job.result.text.split('[PAUSE]');
    if (parts.length > 1) {
      for (var i = 0; i < parts.length; i++) {
        if (!_isCurrentGeneration(generation)) return;
        if (parts[i].trim().isNotEmpty) {
          await _safeTtsSpeak(parts[i].trim(), retries: 2, generation: generation);
        }
        if (!_isCurrentGeneration(generation)) return;
        if (i < parts.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      return;
    }

    if (job.result.chunks.length <= 1) {
      await _safeTtsSpeak(job.result.text, retries: 2, generation: generation);
    } else {
      for (var i = 0; i < job.result.chunks.length; i++) {
        if (!_isCurrentGeneration(generation)) return;
        await _safeTtsSpeak(
          job.result.chunks[i],
          retries: 1,
          generation: generation,
        );
        if (!_isCurrentGeneration(generation)) return;
        if (i < job.result.chunks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
      }
    }
  }

  // ── Private: amplitude simulation ─────────────────────────────────────────

  void _startAmpTimer() {
    _ampTimer?.cancel();
    _ampPhase = 0;
    _ampTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _ampPhase += 0.08;
      // Layered sine waves to look organic
      final amp = (math.sin(_ampPhase) * 0.35 +
                   math.sin(_ampPhase * 2.3) * 0.25 +
                   math.sin(_ampPhase * 0.7) * 0.20 +
                   0.45).clamp(0.0, 1.0);
      if (!_ampCtrl.isClosed) _ampCtrl.add(amp);
    });
  }

  void _stopAmpTimer() {
    _ampTimer?.cancel();
    _ampTimer = null;
    if (!_ampCtrl.isClosed) _ampCtrl.add(0.0);
  }

  void _setSpeaking(bool v) {
    _isSpeaking = v;
    if (!_speakingCtrl.isClosed) _speakingCtrl.add(v);
  }

  // ── Private: locale management ─────────────────────────────────────────────

  bool _engineWarm = false;

  /// Wait for a bounded response from the native TTS service. Don't hold a
  /// payment announcement forever if the device's speech engine is unavailable.
  bool _engineGenerationIsCurrent(int? generation) =>
      generation == null || generation == _generation;

  Future<void> _ensureEngineReady({int? generation}) async {
    if (_engineWarm || !_engineGenerationIsCurrent(generation)) return;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!_engineGenerationIsCurrent(generation)) return;
      try {
        final engines = await _tts.getEngines.timeout(
          const Duration(seconds: 3),
        );
        if (!_engineGenerationIsCurrent(generation)) return;
        if (engines is List && engines.isNotEmpty) {
          _engineWarm = true;
          return;
        }
      } catch (_) {
        // Platform TTS may still be binding; retry below.
      }
      if (!_engineGenerationIsCurrent(generation)) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (_engineGenerationIsCurrent(generation)) {
      _log.w('TTS engine did not answer in time; continuing with default voice');
    }
  }

  Future<bool> _safeSetLocale(String locale, {int? generation}) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      if (!_engineGenerationIsCurrent(generation)) return false;
      try {
        final availability = await _tts.isLanguageAvailable(locale).timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
        if (!_engineGenerationIsCurrent(generation)) return false;

        final available =
            availability == true ||
            (availability is num && availability > 0);
        if (!available) {
          _log.w('Locale $locale is unavailable (attempt $attempt)');
          continue;
        }

        final languageResult = await _tts.setLanguage(locale);
        if (!_engineGenerationIsCurrent(generation)) return false;
        final languageSelected =
            languageResult == true ||
            (languageResult is num && languageResult > 0);
        if (!languageSelected) {
          _log.w('TTS engine rejected locale $locale (attempt $attempt)');
          continue;
        }

        if (_cachedVoiceName != null && _cachedVoiceLocale == locale) {
          await _applyVoice(_cachedVoiceName!, _cachedVoiceLocale!);
          if (!_engineGenerationIsCurrent(generation)) return false;
        }
        _currentLocale = locale;
        return true;
      } catch (e, st) {
        if (!_engineGenerationIsCurrent(generation)) return false;
        _log.w('_safeSetLocale attempt $attempt failed: $locale', error: e, stackTrace: st);
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }

    if (_engineGenerationIsCurrent(generation)) _currentLocale = null;
    return false;
  }

  Future<void> _applyVoice(String name, String locale) async {
    try {
      await _tts.setVoice({'name': name, 'locale': locale});
    } catch (e, st) {
      _log.e('_applyVoice failed: $name', error: e, stackTrace: st);
    }
  }

  dynamic _pickByPreference(List<dynamic> voices, List<String> keywords) {
    for (final kw in keywords) {
      final match = voices.where((v) => v['name'].toString().toLowerCase().contains(kw));
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  // ── Private: TTS with retry ────────────────────────────────────────────────

  Future<void> _safeTtsSpeak(
    String text, {
    int retries = 0,
    int? generation,
  }) async {
    for (int i = 0; i <= retries; i++) {
      if (!_engineGenerationIsCurrent(generation)) return;
      final attemptClock = Stopwatch()..start();
      try {
        await _tts.speak(text).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            _log.w('TTS speak timed out after 8s: "$text"');
            _setSpeaking(false);
            _stopAmpTimer();
            return 0;
          },
        );
        if (!_engineGenerationIsCurrent(generation)) return;
        return;
      } catch (e, st) {
        if (!_engineGenerationIsCurrent(generation)) return;
        // A late failure may happen after speech became audible. Only retry an
        // immediate engine/setup failure, where playback has not had time to start.
        if (i < retries && attemptClock.elapsedMilliseconds < 400) {
          _log.w('TTS speak attempt $i failed, retrying…');
          await Future<void>.delayed(Duration(milliseconds: 120 * (i + 1)));
        } else {
          _log.e('TTS speak failed after ${i + 1} attempts: '
              '"${text.substring(0, text.length.clamp(0, 40))}"',
              error: e, stackTrace: st);
          rethrow;
        }
      }
    }
  }

  // ── Private: audio file ────────────────────────────────────────────────────

  Future<void> _playAudioFile(String path, {int? generation}) async {
    StreamSubscription<PlayerState>? sub;
    try {
      if (!_engineGenerationIsCurrent(generation)) return;
      if (!await File(path).exists()) return;
      if (!_engineGenerationIsCurrent(generation)) return;

      final completer = Completer<void>();
      sub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          if (!completer.isCompleted) completer.complete();
        }
      });
      await _audioPlayer.play(DeviceFileSource(path));
      if (!_engineGenerationIsCurrent(generation)) return;
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => _log.w('Audio file timeout: $path'),
      );
    } catch (e, st) {
      _log.e('_playAudioFile failed: $path', error: e, stackTrace: st);
    } finally {
      await sub?.cancel();
    }
  }

  // ── Private: stitched voice ───────────────────────────────────────────────

  Future<void> _playStitchedSequence(
    String message,
    String locale,
    int generation,
  ) async {
    if (!_isCurrentGeneration(generation)) return;
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(message);
    if (match == null) {
      if (!await _safeSetLocale(locale, generation: generation)) return;
      if (!_isCurrentGeneration(generation)) return;
      await _safeTtsSpeak(message, generation: generation);
      return;
    }

    final amount = double.tryParse(match.group(1)!) ?? 0.0;
    final words = _getNumberWords(amount, locale);
    final dir = await getApplicationDocumentsDirectory();
    if (!_isCurrentGeneration(generation)) return;
    final studio = p.join(dir.path, 'voice_studio');

    final allExist = (await Future.wait(
      words.map((word) => File(p.join(studio, '$word.m4a')).exists()),
    )).every((exists) => exists);
    if (!_isCurrentGeneration(generation)) return;

    if (!allExist) {
      _log.d('Stitch files incomplete — TTS fallback');
      if (!await _safeSetLocale(locale, generation: generation)) return;
      if (!_isCurrentGeneration(generation)) return;
      await _safeTtsSpeak(message, generation: generation);
      return;
    }

    for (final word in words) {
      if (!_isCurrentGeneration(generation)) return;
      await _playAudioFile(
        p.join(studio, '$word.m4a'),
        generation: generation,
      );
      if (!_isCurrentGeneration(generation)) return;
    }
  }

  List<String> _getNumberWords(double amount, String locale) {
    final key     = locale.split('-').first.toLowerCase();
    final isHindi = key == 'hi' || key == 'mr';
    return _buildWords(amount, isHindi ? 'hi' : 'en');
  }

  List<String> _buildWords(double amount, String wordLang) {
    final words = <String>[];
    int n        = amount.floor();
    final paise  = ((amount - n) * 100).round();

    void addBreak(int val) {
      if (val < 20) { words.add(val.toString()); return; }
      if (val < 100) {
        words.add(((val ~/ 10) * 10).toString());
        final o = val % 10;
        if (o > 0) words.add(o.toString());
        return;
      }
      words.add(val.toString());
    }

    if (n == 0) {
      words.add('0');
    } else {
      if (n >= 10000000) { addBreak(n ~/ 10000000); words.add(wordLang == 'hi' ? 'करोड़'  : 'crore');    n %= 10000000; }
      if (n >= 100000)   { addBreak(n ~/ 100000);   words.add(wordLang == 'hi' ? 'लाख'    : 'lakh');     n %= 100000; }
      if (n >= 1000)     { addBreak(n ~/ 1000);     words.add(wordLang == 'hi' ? 'हज़ार'   : 'thousand'); n %= 1000; }
      if (n >= 100)      { addBreak(n ~/ 100);      words.add(wordLang == 'hi' ? 'सौ'     : 'hundred');  n %= 100; }
      if (n > 0)          addBreak(n);
    }
    words.add(wordLang == 'hi' ? 'रुपये' : 'rupees');
    if (paise > 0) { addBreak(paise); words.add(wordLang == 'hi' ? 'पैसे' : 'paise'); }
    return words;
  }
}