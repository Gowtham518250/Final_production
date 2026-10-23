import 'package:flutter/material.dart';

import 'guided_voice_service.dart';
import 'language_provider.dart';

typedef UserGuidanceSelectionContinue =
    Future<void> Function(
      bool guidedMode,
      String languageCode,
      BuildContext pageContext,
    );

class UserGuidanceSelectionPage extends StatefulWidget {
  const UserGuidanceSelectionPage({super.key, required this.onContinue});

  final UserGuidanceSelectionContinue onContinue;

  @override
  State<UserGuidanceSelectionPage> createState() =>
      _UserGuidanceSelectionPageState();
}

class _UserGuidanceSelectionPageState extends State<UserGuidanceSelectionPage> {
  static const _navy = Color(0xFF12386A);
  static const _green = Color(0xFF08B995);
  static const Map<String, Map<String, String>> _copy = {
    'en': {
      'tagline': 'Your Shop, Smarter Everyday',
      'language': 'Language',
      'chooseLanguage': 'Choose your language',
      'title': 'How would you like to use the app?',
      'subtitle': 'Choose the option that feels right for you.',
      'listen': 'Listen to this page',
      'seeMore': 'See more',
      'showLess': 'Show less',
      'independent': 'I can use the app on my own',
      'independentHint': 'I’m comfortable exploring by myself.',
      'guided': 'I need step-by-step guidance',
      'guidedHint': 'Show me what to do as I go.',
      'continue': 'Continue',
      'step': 'STEP 1 / 3',
      'skip': 'Skip',
      'later': 'You can change this later in Settings.',
      'saveError': 'Could not save your choice. Please try again.',
    },
    'te': {
      'tagline': 'మీ దుకాణం, ప్రతి రోజూ మరింత మెరుగ్గా',
      'language': 'భాష',
      'chooseLanguage': 'మీ భాషను ఎంచుకోండి',
      'title': 'మీరు యాప్‌ను ఎలా ఉపయోగించాలనుకుంటున్నారు?',
      'subtitle': 'మీకు సరైనదిగా అనిపించే ఎంపికను ఎంచుకోండి.',
      'listen': 'ఈ పేజీని వినండి',
      'seeMore': 'మరిన్ని చూడండి',
      'showLess': 'తక్కువ చూపించండి',
      'independent': 'నేను యాప్‌ను స్వయంగా ఉపయోగించగలను',
      'independentHint': 'నేనే సులభంగా ఉపయోగించగలను.',
      'guided': 'నాకు దశలవారీగా మార్గదర్శనం కావాలి',
      'guidedHint': 'నేను ముందుకు వెళ్లే కొద్దీ ఏమి చేయాలో చెప్పండి.',
      'continue': 'కొనసాగించండి',
      'step': 'దశ 1 / 3',
      'skip': 'దాటవేయి',
      'later': 'ఈ ఎంపికను తర్వాత సెట్టింగ్‌లలో మార్చవచ్చు.',
      'saveError': 'మీ ఎంపికను సేవ్ చేయలేకపోయాం. మళ్లీ ప్రయత్నించండి.',
    },
    'hi': {
      'tagline': 'आपकी दुकान, हर दिन और बेहतर',
      'language': 'भाषा',
      'chooseLanguage': 'अपनी भाषा चुनें',
      'title': 'आप ऐप का उपयोग कैसे करना चाहेंगे?',
      'subtitle': 'अपने लिए सही विकल्प चुनें।',
      'listen': 'इस पेज को सुनें',
      'seeMore': 'और देखें',
      'showLess': 'कम दिखाएँ',
      'independent': 'मैं ऐप खुद इस्तेमाल कर सकता/सकती हूँ',
      'independentHint': 'मैं खुद ऐप चलाने में सहज हूँ।',
      'guided': 'मुझे हर कदम पर मार्गदर्शन चाहिए',
      'guidedHint': 'आगे बढ़ते समय मुझे बताते रहें कि क्या करना है।',
      'continue': 'जारी रखें',
      'step': 'चरण 1 / 3',
      'skip': 'छोड़ें',
      'later': 'आप इसे बाद में सेटिंग में बदल सकते हैं।',
      'saveError': 'आपकी पसंद सेव नहीं हुई। कृपया फिर से कोशिश करें।',
    },
    'ta': {
      'tagline': 'உங்கள் கடை, தினமும் மேலும் சிறப்பாக',
      'language': 'மொழி',
      'chooseLanguage': 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
      'title': 'செயலியை எப்படிப் பயன்படுத்த விரும்புகிறீர்கள்?',
      'subtitle': 'உங்களுக்கு ஏற்ற விருப்பத்தைத் தேர்ந்தெடுக்கவும்.',
      'listen': 'இந்தப் பக்கத்தைக் கேளுங்கள்',
      'seeMore': 'மேலும் காண்க',
      'showLess': 'குறைவாகக் காட்டு',
      'independent': 'நானே செயலியைப் பயன்படுத்த முடியும்',
      'independentHint': 'நானாகப் பயன்படுத்துவதில் எனக்கு வசதியாக உள்ளது.',
      'guided': 'ஒவ்வொரு படியாகவும் வழிகாட்டுதல் வேண்டும்',
      'guidedHint': 'நான் செல்லச் செல்ல என்ன செய்ய வேண்டும் என்று கூறுங்கள்.',
      'continue': 'தொடரவும்',
      'step': 'படி 1 / 3',
      'skip': 'தவிர்',
      'later': 'இதை பின்னர் அமைப்புகளில் மாற்றலாம்.',
      'saveError':
          'உங்கள் தேர்வைச் சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
    },
    'kn': {
      'tagline': 'ನಿಮ್ಮ ಅಂಗಡಿ, ಪ್ರತಿದಿನ ಇನ್ನಷ್ಟು ಉತ್ತಮ',
      'language': 'ಭಾಷೆ',
      'chooseLanguage': 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      'title': 'ಆ್ಯಪ್ ಅನ್ನು ನೀವು ಹೇಗೆ ಬಳಸಲು ಬಯಸುತ್ತೀರಿ?',
      'subtitle': 'ನಿಮಗೆ ಸರಿಹೊಂದುವ ಆಯ್ಕೆಯನ್ನು ಆರಿಸಿ.',
      'listen': 'ಈ ಪುಟವನ್ನು ಆಲಿಸಿ',
      'seeMore': 'ಇನ್ನಷ್ಟು ನೋಡಿ',
      'showLess': 'ಕಡಿಮೆ ತೋರಿಸಿ',
      'independent': 'ನಾನು ಆ್ಯಪ್ ಅನ್ನು ಸ್ವತಃ ಬಳಸಬಲ್ಲೆ',
      'independentHint': 'ನಾನೇ ಬಳಸಿಕೊಳ್ಳಲು ನನಗೆ ಅನುಕೂಲವಾಗಿದೆ.',
      'guided': 'ಹಂತ ಹಂತದ ಮಾರ್ಗದರ್ಶನ ಬೇಕು',
      'guidedHint': 'ಮುಂದುವರಿಯುವಾಗ ಏನು ಮಾಡಬೇಕೆಂದು ತಿಳಿಸಿ.',
      'continue': 'ಮುಂದುವರಿಸಿ',
      'step': 'ಹಂತ 1 / 3',
      'skip': 'ಬಿಟ್ಟುಬಿಡಿ',
      'later': 'ಇದನ್ನು ನಂತರ ಸೆಟ್ಟಿಂಗ್‌ಗಳಲ್ಲಿ ಬದಲಾಯಿಸಬಹುದು.',
      'saveError': 'ನಿಮ್ಮ ಆಯ್ಕೆಯನ್ನು ಉಳಿಸಲಾಗಲಿಲ್ಲ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    },
    'ml': {
      'tagline': 'നിങ്ങളുടെ കട, ഓരോ ദിവസവും കൂടുതൽ മികവോടെ',
      'language': 'ഭാഷ',
      'chooseLanguage': 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
      'title': 'ആപ്പ് എങ്ങനെ ഉപയോഗിക്കാനാണ് നിങ്ങൾ ആഗ്രഹിക്കുന്നത്?',
      'subtitle': 'നിങ്ങൾക്ക് അനുയോജ്യമായ മാർഗം തിരഞ്ഞെടുക്കുക.',
      'listen': 'ഈ പേജ് കേൾക്കുക',
      'seeMore': 'കൂടുതൽ കാണുക',
      'showLess': 'കുറച്ച് കാണിക്കുക',
      'independent': 'എനിക്ക് ആപ്പ് തനിയെ ഉപയോഗിക്കാം',
      'independentHint': 'സ്വയം ഉപയോഗിക്കാൻ എനിക്ക് ആത്മവിശ്വാസമുണ്ട്.',
      'guided': 'ഘട്ടംഘട്ടമായുള്ള നിർദ്ദേശങ്ങൾ വേണം',
      'guidedHint': 'ഓരോ ഘട്ടത്തിലും എന്ത് ചെയ്യണമെന്ന് പറയുക.',
      'continue': 'തുടരുക',
      'step': 'ഘട്ടം 1 / 3',
      'skip': 'ഒഴിവാക്കുക',
      'later': 'ഇത് പിന്നീട് ക്രമീകരണങ്ങളിൽ മാറ്റാം.',
      'saveError':
          'നിങ്ങളുടെ തിരഞ്ഞെടുപ്പ് സംരക്ഷിക്കാനായില്ല. വീണ്ടും ശ്രമിക്കുക.',
    },
    'mr': {
      'tagline': 'तुमचे दुकान, दररोज अधिक स्मार्ट',
      'language': 'भाषा',
      'chooseLanguage': 'तुमची भाषा निवडा',
      'title': 'तुम्हाला अॅप कसे वापरायचे आहे?',
      'subtitle': 'तुमच्यासाठी योग्य पर्याय निवडा.',
      'listen': 'हे पान ऐका',
      'seeMore': 'आणखी पहा',
      'showLess': 'कमी दाखवा',
      'independent': 'मी अॅप स्वतः वापरू शकतो/शकते',
      'independentHint': 'मला स्वतः अॅप वापरणे सोयीचे वाटते.',
      'guided': 'मला प्रत्येक टप्प्यावर मार्गदर्शन हवे',
      'guidedHint': 'पुढे जाताना काय करायचे ते मला सांगा.',
      'continue': 'पुढे चला',
      'step': 'टप्पा 1 / 3',
      'skip': 'वगळा',
      'later': 'हे तुम्ही नंतर सेटिंग्जमध्ये बदलू शकता.',
      'saveError': 'तुमची निवड जतन करता आली नाही. पुन्हा प्रयत्न करा.',
    },
    'gu': {
      'tagline': 'તમારી દુકાન, દરરોજ વધુ સ્માર્ટ',
      'language': 'ભાષા',
      'chooseLanguage': 'તમારી ભાષા પસંદ કરો',
      'title': 'તમે એપનો ઉપયોગ કેવી રીતે કરવા માંગો છો?',
      'subtitle': 'તમને યોગ્ય લાગે તે વિકલ્પ પસંદ કરો.',
      'listen': 'આ પેજ સાંભળો',
      'seeMore': 'વધુ જુઓ',
      'showLess': 'ઓછું બતાવો',
      'independent': 'હું એપ જાતે વાપરી શકું છું',
      'independentHint': 'મને જાતે એપ વાપરવામાં સરળતા છે.',
      'guided': 'મને પગલાં પ્રમાણે માર્ગદર્શન જોઈએ',
      'guidedHint': 'આગળ વધતાં શું કરવું તે મને જણાવો.',
      'continue': 'આગળ વધો',
      'step': 'પગલું 1 / 3',
      'skip': 'છોડો',
      'later': 'તમે આ પછી સેટિંગ્સમાં બદલી શકો છો.',
      'saveError': 'તમારી પસંદગી સાચવી શકાઈ નથી. ફરી પ્રયાસ કરો.',
    },
    'pa': {
      'tagline': 'ਤੁਹਾਡੀ ਦੁਕਾਨ, ਹਰ ਰੋਜ਼ ਹੋਰ ਬਿਹਤਰ',
      'language': 'ਭਾਸ਼ਾ',
      'chooseLanguage': 'ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ',
      'title': 'ਤੁਸੀਂ ਐਪ ਨੂੰ ਕਿਵੇਂ ਵਰਤਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
      'subtitle': 'ਆਪਣੇ ਲਈ ਢੁੱਕਵਾਂ ਵਿਕਲਪ ਚੁਣੋ।',
      'listen': 'ਇਹ ਪੰਨਾ ਸੁਣੋ',
      'seeMore': 'ਹੋਰ ਵੇਖੋ',
      'showLess': 'ਘੱਟ ਵਿਖਾਓ',
      'independent': 'ਮੈਂ ਐਪ ਆਪਣੇ ਆਪ ਵਰਤ ਸਕਦਾ/ਸਕਦੀ ਹਾਂ',
      'independentHint': 'ਮੈਨੂੰ ਆਪਣੇ ਆਪ ਐਪ ਵਰਤਣ ਵਿੱਚ ਆਸਾਨੀ ਹੈ।',
      'guided': 'ਮੈਨੂੰ ਕਦਮ-ਦਰ-ਕਦਮ ਸੇਧ ਚਾਹੀਦੀ ਹੈ',
      'guidedHint': 'ਅੱਗੇ ਵਧਦੇ ਹੋਏ ਦੱਸੋ ਕਿ ਕੀ ਕਰਨਾ ਹੈ।',
      'continue': 'ਜਾਰੀ ਰੱਖੋ',
      'step': 'ਪੜਾਅ 1 / 3',
      'skip': 'ਛੱਡੋ',
      'later': 'ਤੁਸੀਂ ਇਸਨੂੰ ਬਾਅਦ ਵਿੱਚ ਸੈਟਿੰਗਾਂ ਵਿੱਚ ਬਦਲ ਸਕਦੇ ਹੋ।',
      'saveError': 'ਤੁਹਾਡੀ ਚੋਣ ਸੰਭਾਲੀ ਨਹੀਂ ਜਾ ਸਕੀ। ਮੁੜ ਕੋਸ਼ਿਸ਼ ਕਰੋ।',
    },
    'bn': {
      'tagline': 'আপনার দোকান, প্রতিদিন আরও স্মার্ট',
      'language': 'ভাষা',
      'chooseLanguage': 'আপনার ভাষা বেছে নিন',
      'title': 'আপনি অ্যাপটি কীভাবে ব্যবহার করতে চান?',
      'subtitle': 'আপনার জন্য উপযুক্ত বিকল্পটি বেছে নিন।',
      'listen': 'এই পৃষ্ঠাটি শুনুন',
      'seeMore': 'আরও দেখুন',
      'showLess': 'কম দেখান',
      'independent': 'আমি নিজেই অ্যাপটি ব্যবহার করতে পারি',
      'independentHint': 'নিজে ব্যবহার করতে আমি স্বচ্ছন্দ।',
      'guided': 'ধাপে ধাপে নির্দেশনা চাই',
      'guidedHint': 'এগিয়ে যাওয়ার সময় কী করতে হবে বলুন।',
      'continue': 'চালিয়ে যান',
      'step': 'ধাপ ১ / ৩',
      'skip': 'এড়িয়ে যান',
      'later': 'পরে সেটিংসে এটি পরিবর্তন করতে পারবেন।',
      'saveError': 'আপনার পছন্দ সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।',
    },
  };

  bool _guidedMode = false;
  bool _saving = false;
  String _selectedLanguage = LanguageProvider.defaultLanguageCode;

  Map<String, String> get _labels => _copy[_selectedLanguage]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GuidedVoiceService.instance.speakStep(
          'guidanceChoice',
          _selectedLanguage,
        );
      }
    });
  }

  Future<void> _continue({bool? guidedMode}) async {
    if (_saving) return;
    final selectedGuidedMode = guidedMode ?? _guidedMode;
    setState(() => _saving = true);
    try {
      await widget.onContinue(selectedGuidedMode, _selectedLanguage, context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_labels['saveError']!)));
    }
  }

  void _selectLanguage(String code) {
    setState(() => _selectedLanguage = code);
  }

  Widget _brandHeader() {
    final selectedLanguage = LanguageProvider.languages.firstWhere(
      (language) => language['code'] == _selectedLanguage,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandName(),
                SizedBox(height: 2),
                Text(
                  _labels['tagline']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF74849B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: _labels['chooseLanguage'],
            onSelected: _selectLanguage,
            itemBuilder: (context) => LanguageProvider.languages
                .map(
                  (language) => PopupMenuItem<String>(
                    value: language['code']!,
                    child: Text(
                      '${language['nativeName']}  ·  ${language['name']}',
                    ),
                  ),
                )
                .toList(),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB8D1F2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 19, color: _navy),
                  const SizedBox(width: 5),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labels['language']!,
                        style: TextStyle(color: Color(0xFF74849B), fontSize: 9),
                      ),
                      Text(
                        selectedLanguage['nativeName']!,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF58708F),
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const _ProgressDot(active: true),
                const SizedBox(width: 8),
                const _ProgressDot(active: false),
                const SizedBox(width: 8),
                const _ProgressDot(active: false),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _labels['step']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF74849B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => _continue(guidedMode: false),
            style: TextButton.styleFrom(
              foregroundColor: _navy,
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              side: const BorderSide(color: Color(0xFF9BB7DA)),
              shape: const StadiumBorder(),
            ),
            child: Text(_labels['skip']!),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                const Positioned.fill(child: _ShopIllustration()),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Image.asset(
                    'assets/shop_keeper.png',
                    height: 160,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _labels['title']!,
            style: const TextStyle(
              color: _navy,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              height: 1.04,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _labels['subtitle']!,
            style: const TextStyle(
              color: Color(0xFF71839D),
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => GuidedVoiceService.instance.speakStep(
                      'guidanceChoice',
                      _selectedLanguage,
                    ),
              icon: const Icon(Icons.volume_up_rounded, size: 19),
              label: Text(_labels['listen']!),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green, width: 1.4),
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool guidedMode,
  }) {
    final selected = _guidedMode == guidedMode;
    final color = selected ? _green : const Color(0xFFDCE6F1);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: selected
            ? const Color(0xFFEAF9F6)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _saving
              ? null
              : () => setState(() => _guidedMode = guidedMode),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? const Color(0xFF69C4AF) : color,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFD6F5F1)
                        : const Color(0xFFF0EEFF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: guidedMode
                        ? const Color(0xFF3848CB)
                        : const Color(0xFF078F98),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF71839D),
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? const Color(0xFF16A88A)
                      : const Color(0xFF8796AA),
                  size: 27,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), Color(0xFFF7FAFF), Color(0xFFEAF5FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  _brandHeader(),
                  _stepHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _hero(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                            child: Column(
                              children: [
                                _choice(
                                  title: _labels['independent']!,
                                  subtitle: _labels['independentHint']!,
                                  icon: Icons.touch_app_rounded,
                                  guidedMode: false,
                                ),
                                _choice(
                                  title: _labels['guided']!,
                                  subtitle: _labels['guidedHint']!,
                                  icon: Icons.menu_book_rounded,
                                  guidedMode: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 2),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _saving ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          disabledBackgroundColor: const Color(0xFFB7C8DC),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: _navy.withValues(alpha: 0.24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _labels['continue']!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 25,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _labels['later']!,
                      style: const TextStyle(
                        color: Color(0xFF74849B),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandName extends StatelessWidget {
  const _BrandName();

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'RETAIL ',
          style: TextStyle(color: Color(0xFF163C70)),
        ),
        TextSpan(
          text: 'MIND',
          style: TextStyle(color: Color(0xFF08B995)),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.1,
    ),
  );
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: active ? 14 : 10,
    height: 10,
    decoration: BoxDecoration(
      color: active ? const Color(0xFF08B995) : const Color(0xFFC6D2E0),
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

class _ShopIllustration extends StatelessWidget {
  const _ShopIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 198,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 22,
          right: 0,
          child: Container(
            width: 142,
            height: 142,
            decoration: const BoxDecoration(
              color: Color(0xFFDDEEFF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: 132,
          height: 142,
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFDCE8F5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF12386A).withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Container(
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? const Color(0xFF4387D7)
                            : const Color(0xFF69C4AF),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                            index == 0 || index == 3 ? 9 : 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 35,
                            height: 39,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: const Color(0xFFBED7F2),
                              ),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Color(0xFF3985D4),
                              size: 23,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 29,
                        margin: const EdgeInsets.only(top: 17),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB8DDF1),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF2F6DAB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF69C4AF),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 14,
          left: 0,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF12386A).withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF17A989),
              size: 25,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 9,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2D9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.sell_rounded,
              color: Color(0xFFD99A35),
              size: 21,
            ),
          ),
        ),
      ],
    ),
  );
}
