import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/guided_dictation_button.dart';

void main() {
  group('selectEnglishRecognitionLocale', () {
    test('prefers English (India), independent of selected app language', () {
      expect(
        selectEnglishRecognitionLocale(['te-IN', 'en-US', 'en-IN']),
        'en-IN',
      );
    });

    test(
      'uses an available English locale when preferred locales are absent',
      () {
        expect(selectEnglishRecognitionLocale(['te-IN', 'en-GB']), 'en-GB');
      },
    );

    test('returns null when the device has no English recognition locale', () {
      expect(selectEnglishRecognitionLocale(['te-IN', 'hi-IN']), isNull);
    });
  });
}
