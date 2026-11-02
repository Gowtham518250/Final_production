/// Decides, from microphone level samples, whether a recording contains speech.
///
/// Why: cloud speech models invent text for silence/noise. Uploading a silent
/// clip wastes data and risks a phantom bill line, so the app checks levels
/// first. The backend runs its own ASR-confidence guard as a second layer.
///
/// Pure Dart (no plugin imports) so it can be unit-tested without a device.
/// Levels are dBFS as returned by `Record.getAmplitude().current`
/// (0 = full scale, about -160 = silence).
///
/// The defaults are engineering starting points, NOT calibrated on real shop
/// audio. Tune [absoluteMinDb] / [marginDb] with recordings from the target
/// phones. If no samples could be read the gate fails OPEN (the server guard
/// still applies) so a plugin quirk can never block real billing.
library;

enum VoiceActivityReason { ok, tooShort, silent, noSamples }

class VoiceActivityVerdict {
  const VoiceActivityVerdict({
    required this.hasSpeech,
    required this.reason,
    this.voicedMs = 0,
    this.peakDb,
    this.noiseFloorDb,
  });

  final bool hasSpeech;
  final VoiceActivityReason reason;
  final int voicedMs;
  final double? peakDb;
  final double? noiseFloorDb;

  /// Message for the cashier, or null when the recording may be uploaded.
  String? get userMessage {
    switch (reason) {
      case VoiceActivityReason.tooShort:
        return 'That was too short. Tap the microphone, say the items and quantities, then tap again.';
      case VoiceActivityReason.silent:
        return 'No speech was detected, so nothing was added. Speak closer to the microphone and try again.';
      case VoiceActivityReason.ok:
      case VoiceActivityReason.noSamples:
        return null;
    }
  }
}

class VoiceActivityGate {
  VoiceActivityGate({
    this.sampleIntervalMs = 100,
    this.absoluteMinDb = -42.0,
    this.marginDb = 10.0,
    this.minVoicedMs = 300,
    this.minRecordingMs = 600,
  });

  final int sampleIntervalMs;

  /// A sample can only count as voiced above this level, however quiet the room is.
  final double absoluteMinDb;

  /// ...and must also exceed the room's noise floor by this margin (loud shops).
  final double marginDb;

  /// Voiced time needed to treat the clip as speech.
  final int minVoicedMs;

  /// Recordings shorter than this are taps, not sentences.
  final int minRecordingMs;

  final List<double> _samples = <double>[];

  int get sampleCount => _samples.length;

  void reset() => _samples.clear();

  /// Record one level reading; non-finite values are ignored.
  void addSample(double db) {
    if (db.isNaN || db.isInfinite) return;
    _samples.add(db);
  }

  VoiceActivityVerdict evaluate({required int elapsedMs}) {
    if (elapsedMs < minRecordingMs) {
      return const VoiceActivityVerdict(
        hasSpeech: false,
        reason: VoiceActivityReason.tooShort,
      );
    }
    if (_samples.isEmpty) {
      // Could not read levels: do not block; the server-side guard decides.
      return const VoiceActivityVerdict(
        hasSpeech: true,
        reason: VoiceActivityReason.noSamples,
      );
    }
    final sorted = List<double>.from(_samples)..sort();
    final floor = sorted[((sorted.length - 1) * 0.2).floor()];
    final peak = sorted.last;
    final threshold = floor + marginDb > absoluteMinDb ? floor + marginDb : absoluteMinDb;
    final voiced = _samples.where((s) => s > threshold).length;
    final voicedMs = voiced * sampleIntervalMs;
    final speech = voicedMs >= minVoicedMs;
    return VoiceActivityVerdict(
      hasSpeech: speech,
      reason: speech ? VoiceActivityReason.ok : VoiceActivityReason.silent,
      voicedMs: voicedMs,
      peakDb: peak,
      noiseFloorDb: floor,
    );
  }
}
