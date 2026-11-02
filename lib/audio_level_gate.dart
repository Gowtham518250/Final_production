/// Rejects recordings that contain no meaningful microphone-level activity.
///
/// This is an energy check, not speech recognition. It prevents quiet/silent
/// clips from reaching ASR while allowing sustained speech without assuming
/// that the recording contains quiet gaps.
library;

enum AudioLevelReason { speechLevel, tooShort, lowSignal, noSamples }

class AudioLevelVerdict {
  const AudioLevelVerdict({
    required this.hasSignal,
    required this.reason,
    this.activeMs = 0,
    this.peakDb,
  });

  final bool hasSignal;
  final AudioLevelReason reason;
  final int activeMs;
  final double? peakDb;
}

class AudioLevelGate {
  AudioLevelGate({
    this.absoluteMinDb = -42,
    this.minActiveMs = 250,
    this.minRecordingMs = 400,
    this.maxSampleGapMs = 200,
  });

  final double absoluteMinDb;
  final int minActiveMs;
  final int minRecordingMs;
  final int maxSampleGapMs;
  final List<({int elapsedMs, double db})> _samples = [];

  int get sampleCount => _samples.length;

  void reset() => _samples.clear();

  void addSample(double db, {required int elapsedMs}) {
    if (!db.isFinite || elapsedMs < 0) return;
    if (_samples.isNotEmpty && elapsedMs <= _samples.last.elapsedMs) return;
    _samples.add((elapsedMs: elapsedMs, db: db));
  }

  AudioLevelVerdict evaluate({required int elapsedMs}) {
    if (elapsedMs < minRecordingMs) {
      return const AudioLevelVerdict(
        hasSignal: false,
        reason: AudioLevelReason.tooShort,
      );
    }
    if (_samples.isEmpty) {
      return const AudioLevelVerdict(
        hasSignal: false,
        reason: AudioLevelReason.noSamples,
      );
    }

    var activeMs = 0;
    var peakDb = double.negativeInfinity;
    for (var index = 0; index < _samples.length; index++) {
      final sample = _samples[index];
      if (sample.db > peakDb) peakDb = sample.db;
      if (sample.db < absoluteMinDb) continue;

      final nextElapsedMs = index + 1 < _samples.length
          ? _samples[index + 1].elapsedMs
          : elapsedMs;
      final sampleDurationMs = (nextElapsedMs - sample.elapsedMs)
          .clamp(0, maxSampleGapMs);
      activeMs += sampleDurationMs;
    }

    final hasSignal = activeMs >= minActiveMs;
    return AudioLevelVerdict(
      hasSignal: hasSignal,
      reason: hasSignal ? AudioLevelReason.speechLevel : AudioLevelReason.lowSignal,
      activeMs: activeMs,
      peakDb: peakDb,
    );
  }
}