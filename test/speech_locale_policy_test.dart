import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/speech_locale_policy.dart';

void main() {
  group('speech locale availability policy', () {
    test('matches the exact locale', () {
      expect(
        SpeechLocalePolicy.isAvailable('te-IN', ['en-IN', 'te-IN']),
        isTrue,
      );
    });

    test('normalizes underscores and case in platform locale IDs', () {
      expect(
        SpeechLocalePolicy.isAvailable('te-IN', ['TE_in', 'en_US']),
        isTrue,
      );
    });

    test('accepts the same language when region differs', () {
      expect(
        SpeechLocalePolicy.isAvailable('te-IN', ['te', 'en-US']),
        isTrue,
      );
    });

    test('rejects a missing selected language rather than falling back to English', () {
      expect(
        SpeechLocalePolicy.isAvailable('te-IN', ['en-IN', 'hi-IN']),
        isFalse,
      );
    });

    test('rejects empty requested locale', () {
      expect(SpeechLocalePolicy.isAvailable('', ['en-IN']), isFalse);
    });
  });

  group('selected billing locale mapping', () {
    test('maps supported app languages to explicit speech locales', () {
      const expected = <String, String>{
        'en': 'en-IN',
        'hi': 'hi-IN',
        'te': 'te-IN',
        'ta': 'ta-IN',
        'kn': 'kn-IN',
        'ml': 'ml-IN',
        'mr': 'mr-IN',
        'bn': 'bn-IN',
        'gu': 'gu-IN',
        'pa': 'pa-IN',
      };
      for (final entry in expected.entries) {
        expect(
          SpeechLocalePolicy.toSpeechLocaleCode(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('preserves known explicit region locale and defaults safely', () {
      expect(SpeechLocalePolicy.toSpeechLocaleCode('te-IN'), 'te-IN');
      expect(SpeechLocalePolicy.toSpeechLocaleCode('en_US'), 'en-IN');
      expect(SpeechLocalePolicy.toSpeechLocaleCode('unknown'), 'te-IN');
    });
  });
}
