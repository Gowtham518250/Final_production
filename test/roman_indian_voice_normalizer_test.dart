import 'package:flutter_test/flutter_test.dart';
import '../lib/roman_indian_voice_normalizer.dart';

void main() {
  group('RomanIndianVoiceNormalizer', () {
    test('normalizes Roman Telugu quantity + unit + price', () {
      expect(RomanIndianVoiceNormalizer.normalize('rendu kilolu biyyam yaabhai'), '2 kg rice 50');
    });
    test('normalizes common STT unit spelling', () {
      expect(RomanIndianVoiceNormalizer.normalize('2 killolu rice 50'), '2 kg rice 50');
    });
    test('normalizes Telugu script', () {
      expect(RomanIndianVoiceNormalizer.normalize('రెండు కిలోల బియ్యం యాభై'), '2 kg rice 50');
    });
    test('normalizes mixed Telugu and English', () {
      expect(RomanIndianVoiceNormalizer.normalize('రెండు kg rice 50'), '2 kg rice 50');
    });
    test('normalizes Roman Hindi', () {
      expect(RomanIndianVoiceNormalizer.normalize('do kilo chawal pachaas'), '2 kg rice 50');
    });
    test('normalizes multi-item speech', () {
      expect(RomanIndianVoiceNormalizer.normalize('rendu kilo rice 50 moodu packetlu biscuit 100'), '2 kg rice 50 3 packet biscuit 100');
    });
    test('supports Telugu tens + units', () {
      expect(RomanIndianVoiceNormalizer.normalize('iravai rendu kilo'), '22 kg');
    });
    test('normalizes spoken hundreds through the complete voice normalizer', () {
      expect(RomanIndianVoiceNormalizer.normalize('moodu vandalu biyyam'), '300 rice');
      expect(RomanIndianVoiceNormalizer.normalize('మూడు వందలు బియ్యం'), '300 rice');
    });
    test('normalizes Roman Telugu hundreds to the intended amount', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('3 vandalu biyyam'),
        '300 biyyam',
      );
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('moodu vandalu biyyam'),
        '300 biyyam',
      );
    });
    test('normalizes Telugu-script hundreds without rewriting product words', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('మూడు వందలు బియ్యం'),
        '300 బియ్యం',
      );
    });
    test('normalizes the vandulu spelling without changing the product token', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('3 vandulu bubt'),
        '300 bubt',
      );
    });
    test('supports a remainder after a spoken hundred', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('3 vandalu yabhai rupees'),
        '350 rupees',
      );
    });
    test('does not mistake ordinary English homophones for number words', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('tree vandalu soap'),
        'tree vandalu soap',
      );
    });
  });
    test('normalizes common Telugu ASR variants before scale parsing', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases(
          'ఇండు కిలో పంచేదారా ఆరవే రూపాయలు',
        ),
        'రెండు కిలో పంచదార అరవై రూపాయలు',
      );
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases(
          'ఒక బిరియాని ఆయ్దు ఉందలు',
        ),
        'ఒక బిరియాని 500',
      );
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases(
          'ఒక బిరియాని రేణు ఉందలు',
        ),
        'ఒక బిరియాని 200',
      );
    });
    test('preserves Renu as a name outside a price expression', () {
      expect(
        RomanIndianVoiceNormalizer.normalizeSpokenScalePhrases('రేణు కిలో'),
        'రేణు కిలో',
      );
    });

}
