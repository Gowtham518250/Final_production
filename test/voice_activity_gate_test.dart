import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/voice_activity_gate.dart';

VoiceActivityGate _gateWith(List<double> samples) {
  final gate = VoiceActivityGate();
  for (final s in samples) {
    gate.addSample(s);
  }
  return gate;
}

List<double> _repeat(double db, int n) => List<double>.filled(n, db);

void main() {
  test('silence in a quiet room is rejected', () {
    final v = _gateWith(_repeat(-60, 40)).evaluate(elapsedMs: 4000);
    expect(v.hasSpeech, isFalse);
    expect(v.reason, VoiceActivityReason.silent);
    expect(v.userMessage, isNotNull);
  });

  test('steady loud background noise with no speech on top is rejected', () {
    final v = _gateWith(_repeat(-28, 40)).evaluate(elapsedMs: 4000);
    expect(v.hasSpeech, isFalse);
  });

  test('speech over a quiet room is accepted', () {
    final samples = [..._repeat(-58, 20), ..._repeat(-18, 12), ..._repeat(-58, 8)];
    final v = _gateWith(samples).evaluate(elapsedMs: 4000);
    expect(v.hasSpeech, isTrue);
    expect(v.reason, VoiceActivityReason.ok);
    expect(v.voicedMs, 1200);
    expect(v.userMessage, isNull);
  });

  test('speech louder than steady shop noise is accepted', () {
    final samples = [..._repeat(-35, 25), ..._repeat(-15, 10), ..._repeat(-35, 5)];
    expect(_gateWith(samples).evaluate(elapsedMs: 4000).hasSpeech, isTrue);
  });

  test('a single click or cough spike is not speech', () {
    final samples = [..._repeat(-60, 39), -10];
    expect(_gateWith(samples).evaluate(elapsedMs: 4000).hasSpeech, isFalse);
  });

  test('a recording shorter than the minimum is a tap', () {
    final v = _gateWith(_repeat(-10, 3)).evaluate(elapsedMs: 300);
    expect(v.hasSpeech, isFalse);
    expect(v.reason, VoiceActivityReason.tooShort);
  });

  test('no readable samples fails open so the server guard decides', () {
    final v = VoiceActivityGate().evaluate(elapsedMs: 4000);
    expect(v.hasSpeech, isTrue);
    expect(v.reason, VoiceActivityReason.noSamples);
  });

  test('non-finite samples are ignored', () {
    final gate = VoiceActivityGate()
      ..addSample(double.nan)
      ..addSample(double.negativeInfinity);
    expect(gate.sampleCount, 0);
  });
}
