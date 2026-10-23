import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

String? selectEnglishRecognitionLocale(Iterable<String> localeIds) {
  final normalizedLocales = localeIds
      .map(
        (localeId) => (
          original: localeId,
          normalized: localeId.toLowerCase().replaceAll('_', '-'),
        ),
      )
      .toList();

  for (final preferredLocale in ['en-in', 'en-us']) {
    for (final locale in normalizedLocales) {
      if (locale.normalized == preferredLocale) return locale.original;
    }
  }

  for (final locale in normalizedLocales) {
    if (locale.normalized == 'en' || locale.normalized.startsWith('en-')) {
      return locale.original;
    }
  }
  return null;
}

class GuidedDictationButton extends StatefulWidget {
  const GuidedDictationButton({
    super.key,
    required this.controller,
    required this.languageCode,
    this.color,
    this.showTooltip = true,
    this.scaffoldMessenger,
  });

  final TextEditingController controller;
  final String languageCode;
  final Color? color;
  final bool showTooltip;
  final ScaffoldMessengerState? scaffoldMessenger;

  @override
  State<GuidedDictationButton> createState() => _GuidedDictationButtonState();
}

class _GuidedDictationButtonState extends State<GuidedDictationButton> {
  static const Map<String, String> _tooltips = {
    'en': 'Speak to fill this field',
    'te': 'మాట్లాడి ఈ ఖాళీని పూరించండి',
    'hi': 'बोलकर यह फ़ील्ड भरें',
    'ta': 'பேசி இந்தப் புலத்தை நிரப்பவும்',
    'kn': 'ಮಾತನಾಡಿ ಈ ಜಾಗವನ್ನು ತುಂಬಿಸಿ',
    'ml': 'സംസാരിച്ച് ഈ ഫീൽഡ് പൂരിപ്പിക്കുക',
    'mr': 'बोलून ही जागा भरा',
    'gu': 'બોલીને આ જગ્યા ભરો',
    'pa': 'ਬੋਲ ਕੇ ਇਹ ਖਾਨਾ ਭਰੋ',
    'bn': 'কথা বলে এই ঘরটি পূরণ করুন',
  };

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isStarting = false;

  String get _language =>
      widget.languageCode.toLowerCase().split(RegExp('[-_]')).first;

  void _showMessage(String message) {
    final messenger =
        widget.scaffoldMessenger ?? ScaffoldMessenger.maybeOf(context);
    if (!mounted || messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (_isStarting) return;

    setState(() => _isStarting = true);
    try {
      final available = await _speech.initialize(
        onError: (error) {
          if (mounted) {
            setState(() => _isListening = false);
            _showMessage('Speech recognition failed: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
      );
      if (!available) {
        _showMessage('Speech recognition is unavailable on this device.');
        return;
      }

      final locales = await _speech.locales();
      final selectedLocale = selectEnglishRecognitionLocale(
        locales.map((locale) => locale.localeId),
      );
      if (selectedLocale == null) {
        _showMessage(
          'English speech recognition is not available on this device.',
        );
        return;
      }

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords;
          if (words.isEmpty || !mounted) return;
          widget.controller.value = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: words.length),
          );
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: selectedLocale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      if (mounted) setState(() => _isListening = _speech.isListening);
    } catch (error) {
      _showMessage('Could not start speech recognition: $error');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  void dispose() {
    if (_isListening) unawaited(_speech.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isListening ? Colors.red : widget.color;
    final label = _tooltips[_language] ?? _tooltips['en']!;
    return Semantics(
      label: label,
      button: true,
      child: IconButton(
        tooltip: widget.showTooltip ? label : null,
        visualDensity: VisualDensity.compact,
        onPressed: _isStarting ? null : _toggleListening,
        icon: Icon(
          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: color,
        ),
      ),
    );
  }
}
