import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/guided_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuidedVoiceService', () {
    const languages = <String>[
      'en',
      'te',
      'hi',
      'ta',
      'kn',
      'ml',
      'mr',
      'gu',
      'pa',
      'bn',
    ];
    const steps = <String>[
      'guidanceChoice',
      'languageSelection',
      'login',
      'register',
      'roleSelection',
      'ownerOtp',
      'usernameField',
      'emailField',
      'passwordField',
      'shopNameField',
      'staffPinField',
      'otpField',
      'inputField',
      'afterLogin',
      'sale',
      'inventoryPhoto',
      'saleSaved',
    ];

    test(
      'every supported language has prompts for the full owner workflow',
      () {
        for (final language in languages) {
          for (final step in steps) {
            expect(
              GuidedVoiceService.instructionForScreenGuide(step, language),
              isNotEmpty,
              reason: 'Missing $step guidance for language $language',
            );
          }
        }
      },
    );

    test('sign-in guidance stays on sign-in and registration actions', () {
      final english = GuidedVoiceService.instructionForScreenGuide(
        'login',
        'en',
      );
      expect(english, contains('username or email'));
      expect(english, contains('password'));
      expect(english, contains('Sign In'));
      expect(english, contains('Register'));
      expect(english, isNot(contains('Add Sale')));
    });

    test('normalizes region-specific selected languages', () {
      expect(
        GuidedVoiceService.instructionForScreenGuide('login', 'te-IN'),
        GuidedVoiceService.instructionForScreenGuide('login', 'te'),
      );
      expect(
        GuidedVoiceService.instructionForScreenGuide('ownerOtp', 'te-IN'),
        contains('ఆరు అంకెల'),
      );
    });

    test('maps a selected language to its matching speech locale', () {
      expect(GuidedVoiceService.localeForLanguageCode('te'), 'te-IN');
      expect(GuidedVoiceService.localeForLanguageCode('te-IN'), 'te-IN');
      expect(GuidedVoiceService.localeForLanguageCode('en'), 'en-IN');
    });

    test('does not substitute English for missing selected-language copy', () {
      expect(
        GuidedVoiceService.instructionForScreenGuide('missingPrompt', 'te'),
        isEmpty,
      );
    });

    test(
      'login and verification prompts do not speak private field values',
      () {
        final login = GuidedVoiceService.instructionForScreenGuide(
          'login',
          'te',
        );
        final role = GuidedVoiceService.instructionForScreenGuide(
          'roleSelection',
          'te',
        );
        final otp = GuidedVoiceService.instructionForScreenGuide(
          'ownerOtp',
          'te',
        );

        expect(login, isNot(contains('Add Sale')));
        expect(role, isNot(contains('@')));
        expect(otp, isNot(contains('@')));
        expect(
          GuidedVoiceService.instructionForScreenGuide('emailField', 'te'),
          contains('ఇమెయిల్ చిరునామా'),
        );
      },
    );

    test('unsupported locale safely falls back to English copy', () {
      expect(
        GuidedVoiceService.instructionFor('sale', 'xx'),
        GuidedVoiceService.instructionFor('sale', 'en'),
      );
    });

    test(
      'one guidance request speaks once and exposes playback state',
      () async {
        final service = GuidedVoiceService.instance;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var speechCount = 0;
        messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          switch (call.method) {
            case 'getLanguages':
              return <String>['en-IN'];
            case 'isLanguageAvailable':
              return true;
            case 'speak':
              speechCount++;
              return 1;
            default:
              return 1;
          }
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            const MethodChannel('flutter_tts'),
            null,
          );
        });

        final playbackStates = <(bool, bool)>[];
        void recordPlaybackState() {
          playbackStates.add((service.isStarting, service.isSpeaking));
        }

        service.addListener(recordPlaybackState);
        addTearDown(() => service.removeListener(recordPlaybackState));

        await service.speakStep('login', 'en');

        expect(speechCount, 1);
        expect(playbackStates.first, (true, false));
        expect(playbackStates.last, (false, true));

        await service.stop();
        expect(playbackStates.last, (false, false));
      },
    );
  });
}
