import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/audio_level_gate.dart';

AudioLevelGate _gateWith(List<double> values) {
  final gate = AudioLevelGate();
  for (var index = 0; index < values.length; index++) {
    gate.addSample(values[index], elapsedMs: index * 100);
  }
  return gate;
}

void main() {
  test('silent recording is rejected', () {
    final verdict = _gateWith(
      List<double>.filled(40, -60),
    ).evaluate(elapsedMs: 4000);

    expect(verdict.hasSignal, isFalse);
    expect(verdict.reason, AudioLevelReason.lowSignal);
  });

  test('sustained speech level is accepted without quiet gaps', () {
    final verdict = _gateWith(
      List<double>.filled(40, -25),
    ).evaluate(elapsedMs: 4000);

    expect(verdict.hasSignal, isTrue);
    expect(verdict.activeMs, greaterThanOrEqualTo(250));
  });

  test('a single loud click is not enough activity', () {
    final samples = [...List<double>.filled(39, -60), -10.0];
    final verdict = _gateWith(samples).evaluate(elapsedMs: 4000);

    expect(verdict.hasSignal, isFalse);
  });

  test('recording shorter than minimum is rejected', () {
    final verdict = AudioLevelGate().evaluate(elapsedMs: 300);

    expect(verdict.hasSignal, isFalse);
    expect(verdict.reason, AudioLevelReason.tooShort);
  });

  test('unreadable microphone levels fail closed', () {
    final verdict = AudioLevelGate().evaluate(elapsedMs: 4000);

    expect(verdict.hasSignal, isFalse);
    expect(verdict.reason, AudioLevelReason.noSamples);
  });

  test('non-finite samples are ignored', () {
    final gate = AudioLevelGate()
      ..addSample(double.nan, elapsedMs: 0)
      ..addSample(double.negativeInfinity, elapsedMs: 100);

    expect(gate.sampleCount, 0);
  });
}
