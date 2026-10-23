import 'package:flutter/material.dart';

import 'guided_voice_service.dart';

class GuidedSpeakButton extends StatelessWidget {
  const GuidedSpeakButton({
    super.key,
    required this.step,
    required this.languageCode,
    this.color,
  });

  final String step;
  final String languageCode;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'en': 'Listen to field instructions',
      'te': 'ఈ ఖాళీ సూచనలను వినండి',
      'hi': 'इस खाने के निर्देश सुनें',
      'ta': 'இந்தப் புலத்திற்கான வழிமுறைகளைக் கேளுங்கள்',
      'kn': 'ಈ ಜಾಗದ ಸೂಚನೆಗಳನ್ನು ಕೇಳಿ',
      'ml': 'ഈ ഫീൽഡിന്റെ നിർദ്ദേശങ്ങൾ കേൾക്കുക',
      'mr': 'या जागेच्या सूचना ऐका',
      'gu': 'આ જગ્યાની સૂચનાઓ સાંભળો',
      'pa': 'ਇਸ ਖਾਨੇ ਦੀਆਂ ਹਦਾਇਤਾਂ ਸੁਣੋ',
      'bn': 'এই ঘরের নির্দেশনা শুনুন',
    };
    final language = languageCode.toLowerCase().split(RegExp('[-_]')).first;
    return IconButton(
      tooltip: labels[language] ?? labels['en']!,
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final voice = GuidedVoiceService.instance;
        if (voice.isSpeaking) {
          await voice.stop();
        } else {
          await voice.speakStep(step, languageCode);
        }
      },
      icon: Icon(Icons.volume_up_rounded, color: color),
    );
  }
}
