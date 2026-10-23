import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Spoken, step-by-step guidance for users who prefer to hear app instructions.
///
/// Only generic instructions are spoken; field contents, passwords, email
/// addresses and customer data are never passed to this service.
class GuidedVoiceService extends ChangeNotifier {
  GuidedVoiceService._() {
    _tts.setStartHandler(() => _updatePlaybackState(speaking: true));
    _tts.setCompletionHandler(() => _updatePlaybackState(speaking: false));
    _tts.setCancelHandler(() => _updatePlaybackState(speaking: false));
    _tts.setErrorHandler((_) => _updatePlaybackState(speaking: false));
  }

  static final GuidedVoiceService instance = GuidedVoiceService._();
  static const String guidedModePreferenceKey = 'guided_voice_mode_enabled';

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _isStarting = false;
  int _requestVersion = 0;
  final Map<String, Future<String?>> _localeTasks = {};
  Future<void>? _engineSetup;

  bool get isSpeaking => _isSpeaking;
  bool get isStarting => _isStarting;

  void _updatePlaybackState({required bool speaking}) {
    if (!speaking && _isStarting) return;
    _isSpeaking = speaking;
    if (speaking) _isStarting = false;
    notifyListeners();
  }

  static const Map<String, String> _localeByLanguage = {
    'en': 'en-IN',
    'te': 'te-IN',
    'hi': 'hi-IN',
    'ta': 'ta-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'mr': 'mr-IN',
    'gu': 'gu-IN',
    'pa': 'pa-IN',
    'bn': 'bn-IN',
  };

  static String? localeForLanguageCode(String languageCode) {
    final normalized = languageCode.toLowerCase().replaceAll('_', '-');
    final baseCode = normalized.split('-').first;
    return _localeByLanguage[baseCode];
  }

  /// Keep each prompt short and actionable. The same language registry is used
  /// by LanguageProvider, so guidance follows the user's selected locale.
  static const Map<String, Map<String, String>> _copy = {
    'en': {
      'languageSelection':
          'Choose your language, then tap Continue. You can change it later in Settings.',
      'login':
          'Enter your username or email and password, then tap Sign In. If you do not have an account, tap Register.',
      'register':
          'Enter your name, email, password, and shop name if needed. Then tap Register.',
      'afterLogin':
          'Open Add Sale, choose a product, enter the quantity, review the total, choose payment, and save the sale.',
      'sale':
          'Select a product, add the quantity, review the total, choose a payment method, then save the sale.',
      'inventoryPhoto':
          'Press Take Photo or Choose Photo, then add the product details and save it.',
      'saleSaved':
          'Your sale has been saved. You can review it in the bills section.',
    },
    'te': {
      'languageSelection':
          'రిటైల్ మైండ్‌కు స్వాగతం. మీకు బాగా అర్థమయ్యే భాషను ఎంచుకుని కొనసాగించండి నొక్కండి. తర్వాత సెట్టింగ్స్‌లో భాషను మార్చవచ్చు.',
      'login':
          'మీ యూజర్ పేరు లేదా ఇమెయిల్, పాస్‌వర్డ్ నమోదు చేసి Sign In నొక్కండి. ఖాతా లేకపోతే Register నొక్కండి.',
      'register':
          'మీ యూజర్ పేరు, ఇమెయిల్, పాస్‌వర్డ్, అవసరమైతే దుకాణం పేరు నమోదు చేసి Register నొక్కండి. మీ పాస్‌వర్డ్‌ను రహస్యంగా ఉంచండి.',
      'afterLogin':
          'మీరు లాగిన్ అయ్యారు. Add Sale తెరవండి. ఉత్పత్తి ఎంచుకుని పరిమాణం నమోదు చేయండి. బిల్లు మొత్తం చూసి చెల్లింపు విధానం ఎంచుకోండి. డబ్బు నిజంగా అందిన తర్వాత మాత్రమే చెల్లింపును నిర్ధారించండి. తర్వాత Save Sales నొక్కండి. ఈ సూచనలను మళ్లీ వినడానికి స్పీకర్ బటన్ నొక్కండి.',
      'sale':
          'అమ్మకాన్ని నమోదు చేయడానికి బిల్లులో ఉత్పత్తి ఎంచుకోండి. పరిమాణం నమోదు చేసి అవసరమైన ప్రతి ఉత్పత్తిని జోడించండి. మొత్తం పరిశీలించి Cash లేదా U P I ఎంచుకోండి. డబ్బు అందిన తర్వాత మాత్రమే చెల్లింపును నిర్ధారించండి. తర్వాత Save Sales నొక్కండి. ఇంటర్నెట్ లేకపోతే అమ్మకం సమకాలీకరణ కోసం క్యూలో ఉంచబడుతుంది.',
      'inventoryPhoto':
          'ఇన్వెంటరీలో ఉత్పత్తి ఫోటో తీయడానికి Take Photo నొక్కండి. ఇప్పటికే ఉన్న ఫోటో ఎంచుకోవడానికి Choose Photo నొక్కండి. Add Product నొక్కే ముందు ఉత్పత్తి పేరు, అమ్మకపు ధర, కొనుగోలు ధర సరిచూడండి.',
      'saleSaved':
          'మీ అమ్మకం సేవ్ అయింది. మరో అమ్మకం ప్రారంభించవచ్చు లేదా సేవ్ చేసిన లావాదేవీని చూడటానికి బిల్లుల విభాగం తెరవవచ్చు.',
    },
    'hi': {
      'languageSelection':
          'रिटेल माइंड में आपका स्वागत है। जिस भाषा को आप सबसे अच्छी तरह समझते हैं, उसे चुनें और जारी रखें दबाएँ। आप बाद में सेटिंग्स में भाषा बदल सकते हैं।',
      'login':
          'अपना यूज़रनेम या ईमेल और पासवर्ड भरें, फिर Sign In दबाएँ। खाता नहीं है तो Register दबाएँ।',
      'register':
          'अपना यूज़रनेम, ईमेल, पासवर्ड और दुकान हो तो उसका नाम भरें। फिर Register दबाएँ। अपना पासवर्ड गुप्त रखें।',
      'afterLogin':
          'आप साइन इन हो गए हैं। Add Sale खोलें। उत्पाद और मात्रा चुनें, बिल की कुल राशि देखें और भुगतान का तरीका चुनें। पैसा मिलने के बाद ही भुगतान की पुष्टि करें। फिर Save Sales दबाएँ। इन चरणों को दोबारा सुनने के लिए स्पीकर बटन दबाएँ।',
      'sale':
          'बिक्री दर्ज करने के लिए बिल में उत्पाद चुनें और उसकी मात्रा भरें। हर उत्पाद के लिए यही करें। कुल राशि जाँचें, Cash या U P I चुनें और पैसा मिलने के बाद ही भुगतान की पुष्टि करें। फिर Save Sales दबाएँ। इंटरनेट न होने पर बिक्री सिंक होने के लिए कतार में रहेगी।',
      'inventoryPhoto':
          'इन्वेंटरी में उत्पाद की नई तस्वीर लेने के लिए Take Photo दबाएँ, या अपने डिवाइस से तस्वीर चुनने के लिए Choose Photo दबाएँ। Add Product दबाने से पहले उत्पाद का नाम, बिक्री मूल्य और खरीद मूल्य जाँचें।',
      'saleSaved':
          'आपकी बिक्री सेव हो गई है। आप अगली बिक्री शुरू कर सकते हैं या सेव किए गए लेन-देन को देखने के लिए Bills खोल सकते हैं।',
    },
    'ta': {
      'languageSelection':
          'Retail Mind-க்கு வரவேற்கிறோம். உங்களுக்கு நன்றாகப் புரியும் மொழியைத் தேர்ந்தெடுத்து Continue என்பதை அழுத்தவும். பின்னர் Settings-ல் மொழியை மாற்றலாம்.',
      'login':
          'உங்கள் பயனர்பெயர் அல்லது மின்னஞ்சல் மற்றும் கடவுச்சொல்லை உள்ளிட்டு Sign In-ஐத் தட்டவும். கணக்கு இல்லையெனில் Register-ஐத் தட்டவும்.',
      'register':
          'உங்கள் பயனர்பெயர், மின்னஞ்சல், கடவுச்சொல் மற்றும் கடை இருந்தால் அதன் பெயரை உள்ளிட்டு Register-ஐத் தட்டவும். கடவுச்சொல்லை ரகசியமாக வைத்திருக்கவும்.',
      'afterLogin':
          'நீங்கள் உள்நுழைந்துவிட்டீர்கள். Add Sale திறக்கவும். பொருளையும் அளவையும் தேர்ந்தெடுத்து மொத்தத்தைச் சரிபார்க்கவும். கட்டண முறையைத் தேர்ந்தெடுத்து பணம் கிடைத்த பிறகே கட்டணத்தை உறுதிப்படுத்தவும். பின்னர் Save Sales அழுத்தவும். மீண்டும் கேட்க ஸ்பீக்கர் பொத்தானை அழுத்தவும்.',
      'sale':
          'விற்பனையைப் பதிவு செய்ய பில்லில் ஒரு பொருளைத் தேர்ந்தெடுத்து அளவை உள்ளிடவும். தேவையான அனைத்து பொருட்களுக்கும் இதைச் செய்யவும். மொத்தத்தைச் சரிபார்த்து Cash அல்லது U P I தேர்ந்தெடுக்கவும். பணம் கிடைத்த பிறகே கட்டணத்தை உறுதிப்படுத்தி Save Sales அழுத்தவும். இணையம் இல்லாவிட்டால் ஒத்திசைவுக்காக விற்பனை வரிசையில் இருக்கும்.',
      'inventoryPhoto':
          'Inventory-ல் புதிய தயாரிப்பு படம் எடுக்க Take Photo அழுத்தவும் அல்லது ஏற்கனவே உள்ள படத்தைத் தேர்வு செய்ய Choose Photo அழுத்தவும். Add Product அழுத்துவதற்கு முன் பெயர் மற்றும் விலைகளைச் சரிபார்க்கவும்.',
      'saleSaved':
          'உங்கள் விற்பனை சேமிக்கப்பட்டது. அடுத்த விற்பனையைத் தொடங்கலாம் அல்லது சேமித்த பரிவர்த்தனையைப் பார்க்க Bills திறக்கலாம்.',
    },
    'kn': {
      'languageSelection':
          'Retail Mind ಗೆ ಸ್ವಾಗತ. ನಿಮಗೆ ಚೆನ್ನಾಗಿ ಅರ್ಥವಾಗುವ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ ಮತ್ತು Continue ಒತ್ತಿರಿ. ನಂತರ Settings ನಲ್ಲಿ ಭಾಷೆಯನ್ನು ಬದಲಾಯಿಸಬಹುದು.',
      'login':
          'ನಿಮ್ಮ ಬಳಕೆದಾರ ಹೆಸರು ಅಥವಾ ಇಮೇಲ್ ಮತ್ತು ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ Sign In ಒತ್ತಿ. ಖಾತೆ ಇಲ್ಲದಿದ್ದರೆ Register ಒತ್ತಿ.',
      'register':
          'ನಿಮ್ಮ ಬಳಕೆದಾರ ಹೆಸರು, ಇಮೇಲ್, ಪಾಸ್‌ವರ್ಡ್ ಮತ್ತು ಅಂಗಡಿ ಇದ್ದರೆ ಅದರ ಹೆಸರನ್ನು ನಮೂದಿಸಿ Register ಒತ್ತಿ. ಪಾಸ್‌ವರ್ಡ್ ಗೌಪ್ಯವಾಗಿಡಿ.',
      'afterLogin':
          'ನೀವು ಸೈನ್ ಇನ್ ಆಗಿದ್ದೀರಿ. Add Sale ತೆರೆಯಿರಿ. ಉತ್ಪನ್ನ ಮತ್ತು ಪ್ರಮಾಣ ಆಯ್ಕೆಮಾಡಿ, ಒಟ್ಟು ಪರಿಶೀಲಿಸಿ, ಪಾವತಿ ವಿಧಾನ ಆರಿಸಿ. ಹಣ ಬಂದ ನಂತರ ಮಾತ್ರ ಪಾವತಿಯನ್ನು ದೃಢೀಕರಿಸಿ. ನಂತರ Save Sales ಒತ್ತಿರಿ. ಮತ್ತೆ ಕೇಳಲು ಸ್ಪೀಕರ್ ಬಟನ್ ಒತ್ತಿರಿ.',
      'sale':
          'ಮಾರಾಟ ದಾಖಲಿಸಲು ಬಿಲ್‌ನಲ್ಲಿ ಉತ್ಪನ್ನ ಆಯ್ಕೆಮಾಡಿ ಪ್ರಮಾಣ ನಮೂದಿಸಿ. ಪ್ರತಿಯೊಂದು ಉತ್ಪನ್ನಕ್ಕೂ ಹೀಗೆ ಮಾಡಿ. ಒಟ್ಟು ಪರಿಶೀಲಿಸಿ Cash ಅಥವಾ U P I ಆಯ್ಕೆಮಾಡಿ. ಹಣ ಬಂದ ನಂತರ ಮಾತ್ರ ಪಾವತಿಯನ್ನು ಖಚಿತಪಡಿಸಿ Save Sales ಒತ್ತಿರಿ. ಇಂಟರ್ನೆಟ್ ಇಲ್ಲದಿದ್ದರೆ ಮಾರಾಟ ಸಿಂಕ್‌ಗಾಗಿ ಸಾಲಿನಲ್ಲಿ ಉಳಿಯುತ್ತದೆ.',
      'inventoryPhoto':
          'Inventory ನಲ್ಲಿ ಉತ್ಪನ್ನದ ಫೋಟೋ ತೆಗೆಯಲು Take Photo ಒತ್ತಿ ಅಥವಾ ಈಗಿರುವ ಫೋಟೋ ಆಯ್ಕೆ ಮಾಡಲು Choose Photo ಒತ್ತಿ. Add Product ಒತ್ತುವ ಮೊದಲು ಉತ್ಪನ್ನದ ಹೆಸರು ಮತ್ತು ಬೆಲೆಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.',
      'saleSaved':
          'ನಿಮ್ಮ ಮಾರಾಟ ಉಳಿಸಲಾಗಿದೆ. ಮತ್ತೊಂದು ಮಾರಾಟ ಪ್ರಾರಂಭಿಸಬಹುದು ಅಥವಾ ಉಳಿಸಿದ ವ್ಯವಹಾರವನ್ನು ನೋಡಲು Bills ತೆರೆಯಬಹುದು.',
    },
    'ml': {
      'languageSelection':
          'Retail Mind-ലേക്ക് സ്വാഗതം. നിങ്ങൾക്ക് നന്നായി മനസ്സിലാകുന്ന ഭാഷ തിരഞ്ഞെടുക്കി Continue അമർത്തുക. പിന്നീട് Settings-ൽ ഭാഷ മാറ്റാം.',
      'login':
          'നിങ്ങളുടെ ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഇമെയിലും പാസ്‌വേഡും നൽകി Sign In അമർത്തുക. അക്കൗണ്ട് ഇല്ലെങ്കിൽ Register അമർത്തുക.',
      'register':
          'നിങ്ങളുടെ ഉപയോക്തൃനാമം, ഇമെയിൽ, പാസ്‌വേഡ്, കടയുണ്ടെങ്കിൽ അതിന്റെ പേര് എന്നിവ നൽകി Register അമർത്തുക. പാസ്‌വേഡ് രഹസ്യമായി സൂക്ഷിക്കുക.',
      'afterLogin':
          'നിങ്ങൾ സൈൻ ഇൻ ചെയ്തു. Add Sale തുറക്കുക. ഉൽപ്പന്നവും അളവും തിരഞ്ഞെടുക്കുക, ആകെ തുക പരിശോധിക്കുക, പണമടയ്ക്കൽ രീതി തിരഞ്ഞെടുക്കുക. പണം ലഭിച്ചശേഷം മാത്രം പണമടച്ചതായി സ്ഥിരീകരിക്കുക. തുടർന്ന് Save Sales അമർത്തുക. വീണ്ടും കേൾക്കാൻ സ്പീക്കർ ബട്ടൺ അമർത്തുക.',
      'sale':
          'വിൽപ്പന രേഖപ്പെടുത്താൻ ബില്ലിൽ ഒരു ഉൽപ്പന്നം തിരഞ്ഞെടുക്കുകയും അളവ് നൽകുകയും ചെയ്യുക. എല്ലാ ഉൽപ്പന്നങ്ങൾക്കും ആവർത്തിക്കുക. ആകെ തുക പരിശോധിച്ച് Cash അല്ലെങ്കിൽ U P I തിരഞ്ഞെടുക്കുക. പണം ലഭിച്ചശേഷം മാത്രം സ്ഥിരീകരിച്ച് Save Sales അമർത്തുക. ഇന്റർനെറ്റ് ഇല്ലെങ്കിൽ വിൽപ്പന സിങ്കിനായി ക്യൂവിൽ തുടരും.',
      'inventoryPhoto':
          'Inventory-ൽ ഉൽപ്പന്നത്തിന്റെ ചിത്രം എടുക്കാൻ Take Photo അമർത്തുക, അല്ലെങ്കിൽ നിലവിലുള്ള ചിത്രം തിരഞ്ഞെടുക്കാൻ Choose Photo അമർത്തുക. Add Product അമർത്തുന്നതിന് മുമ്പ് പേരും വിലകളും പരിശോധിക്കുക.',
      'saleSaved':
          'നിങ്ങളുടെ വിൽപ്പന സംരക്ഷിച്ചു. അടുത്ത വിൽപ്പന തുടങ്ങാം അല്ലെങ്കിൽ സംരക്ഷിച്ച ഇടപാട് കാണാൻ Bills തുറക്കാം.',
    },
    'mr': {
      'languageSelection':
          'Retail Mind मध्ये आपले स्वागत आहे. तुम्हाला सर्वात चांगली समजणारी भाषा निवडा आणि Continue दाबा. नंतर Settings मध्ये भाषा बदलू शकता.',
      'login':
          'तुमचे वापरकर्तानाव किंवा ईमेल आणि पासवर्ड भरा, नंतर Sign In दाबा. खाते नसेल तर Register दाबा.',
      'register':
          'तुमचे वापरकर्तानाव, ईमेल, पासवर्ड आणि दुकान असल्यास त्याचे नाव भरा. नंतर Register दाबा. पासवर्ड गुप्त ठेवा.',
      'afterLogin':
          'तुम्ही साइन इन केले आहे. Add Sale उघडा. उत्पादन आणि प्रमाण निवडा, एकूण रक्कम तपासा आणि पेमेंट पद्धत निवडा. पैसे मिळाल्यानंतरच पेमेंटची पुष्टी करा. नंतर Save Sales दाबा. पुन्हा ऐकण्यासाठी स्पीकर बटण दाबा.',
      'sale':
          'विक्री नोंदवण्यासाठी बिलमध्ये उत्पादन निवडा आणि प्रमाण भरा. प्रत्येक उत्पादनासाठी हे करा. एकूण रक्कम तपासा, Cash किंवा U P I निवडा आणि पैसे मिळाल्यानंतरच पेमेंट पुष्टी करा. नंतर Save Sales दाबा. इंटरनेट नसल्यास विक्री सिंकसाठी रांगेत राहील.',
      'inventoryPhoto':
          'Inventory मध्ये उत्पादनाचा फोटो काढण्यासाठी Take Photo दाबा किंवा आधीचा फोटो निवडण्यासाठी Choose Photo दाबा. Add Product दाबण्यापूर्वी नाव आणि किंमती तपासा.',
      'saleSaved':
          'तुमची विक्री जतन झाली आहे. पुढील विक्री सुरू करा किंवा जतन केलेला व्यवहार पाहण्यासाठी Bills उघडा.',
    },
    'gu': {
      'languageSelection':
          'Retail Mind માં આપનું સ્વાગત છે. તમને સૌથી સારી રીતે સમજાતી ભાષા પસંદ કરો અને Continue દબાવો. પછી Settings માં ભાષા બદલી શકો છો.',
      'login':
          'તમારું વપરાશકર્તા નામ અથવા ઇમેઇલ અને પાસવર્ડ દાખલ કરો, પછી Sign In દબાવો. ખાતું ન હોય તો Register દબાવો.',
      'register':
          'તમારું વપરાશકર્તા નામ, ઇમેઇલ, પાસવર્ડ અને દુકાન હોય તો તેનું નામ દાખલ કરીને Register દબાવો. પાસવર્ડ ગુપ્ત રાખો.',
      'afterLogin':
          'તમે સાઇન ઇન થયા છો. Add Sale ખોલો. ઉત્પાદન અને જથ્થો પસંદ કરો, કુલ રકમ તપાસો અને ચુકવણી રીત પસંદ કરો. પૈસા મળ્યા પછી જ ચુકવણીની પુષ્ટિ કરો. પછી Save Sales દબાવો. ફરી સાંભળવા સ્પીકર બટન દબાવો.',
      'sale':
          'વેચાણ નોંધવા બિલમાં ઉત્પાદન પસંદ કરો અને જથ્થો દાખલ કરો. દરેક ઉત્પાદન માટે આવું કરો. કુલ રકમ તપાસો, Cash અથવા U P I પસંદ કરો અને પૈસા મળ્યા પછી જ ચુકવણીની પુષ્ટિ કરીને Save Sales દબાવો. ઇન્ટરનેટ ન હોય તો વેચાણ સિંક માટે કતારમાં રહેશે.',
      'inventoryPhoto':
          'Inventory માં ઉત્પાદનનો ફોટો લેવા Take Photo દબાવો અથવા પહેલેથી રહેલો ફોટો પસંદ કરવા Choose Photo દબાવો. Add Product દબાવતા પહેલાં નામ અને કિંમતો તપાસો.',
      'saleSaved':
          'તમારું વેચાણ સાચવાયું છે. બીજી વેચાણ શરૂ કરો અથવા સાચવેલી લેવડદેવડ જોવા Bills ખોલો.',
    },
    'pa': {
      'languageSelection':
          'Retail Mind ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ। ਆਪਣੀ ਸਮਝ ਵਾਲੀ ਭਾਸ਼ਾ ਚੁਣੋ ਅਤੇ Continue ਦਬਾਓ। ਤੁਸੀਂ ਬਾਅਦ ਵਿੱਚ Settings ਵਿੱਚ ਭਾਸ਼ਾ ਬਦਲ ਸਕਦੇ ਹੋ।',
      'login':
          'ਆਪਣਾ ਯੂਜ਼ਰਨੇਮ ਜਾਂ ਈਮੇਲ ਅਤੇ ਪਾਸਵਰਡ ਦਰਜ ਕਰੋ, ਫਿਰ Sign In ਦਬਾਓ। ਖਾਤਾ ਨਹੀਂ ਹੈ ਤਾਂ Register ਦਬਾਓ।',
      'register':
          'ਆਪਣਾ ਯੂਜ਼ਰਨੇਮ, ਈਮੇਲ, ਪਾਸਵਰਡ ਅਤੇ ਜੇ ਦੁਕਾਨ ਹੈ ਤਾਂ ਉਸਦਾ ਨਾਮ ਦਰਜ ਕਰੋ। ਫਿਰ Register ਦਬਾਓ। ਪਾਸਵਰਡ ਗੁਪਤ ਰੱਖੋ।',
      'afterLogin':
          'ਤੁਸੀਂ ਸਾਈਨ ਇਨ ਹੋ ਗਏ ਹੋ। Add Sale ਖੋਲ੍ਹੋ। ਉਤਪਾਦ ਅਤੇ ਮਾਤਰਾ ਚੁਣੋ, ਕੁੱਲ ਰਕਮ ਵੇਖੋ ਅਤੇ ਭੁਗਤਾਨ ਦਾ ਤਰੀਕਾ ਚੁਣੋ। ਪੈਸੇ ਮਿਲਣ ਤੋਂ ਬਾਅਦ ਹੀ ਭੁਗਤਾਨ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ। ਫਿਰ Save Sales ਦਬਾਓ। ਦੁਬਾਰਾ ਸੁਣਨ ਲਈ ਸਪੀਕਰ ਬਟਨ ਦਬਾਓ।',
      'sale':
          'ਵਿਕਰੀ ਦਰਜ ਕਰਨ ਲਈ ਬਿੱਲ ਵਿੱਚ ਉਤਪਾਦ ਚੁਣੋ ਅਤੇ ਮਾਤਰਾ ਭਰੋ। ਹਰ ਉਤਪਾਦ ਲਈ ਦੁਹਰਾਓ। ਕੁੱਲ ਰਕਮ ਵੇਖੋ, Cash ਜਾਂ U P I ਚੁਣੋ ਅਤੇ ਪੈਸੇ ਮਿਲਣ ਤੋਂ ਬਾਅਦ ਹੀ ਪੁਸ਼ਟੀ ਕਰਕੇ Save Sales ਦਬਾਓ। ਇੰਟਰਨੈੱਟ ਨਾ ਹੋਣ ਤੇ ਵਿਕਰੀ ਸਿੰਕ ਲਈ ਕਤਾਰ ਵਿੱਚ ਰਹੇਗੀ।',
      'inventoryPhoto':
          'Inventory ਵਿੱਚ ਉਤਪਾਦ ਦੀ ਤਸਵੀਰ ਲੈਣ ਲਈ Take Photo ਦਬਾਓ ਜਾਂ ਪਹਿਲਾਂ ਤੋਂ ਮੌਜੂਦ ਤਸਵੀਰ ਚੁਣਨ ਲਈ Choose Photo ਦਬਾਓ। Add Product ਤੋਂ ਪਹਿਲਾਂ ਨਾਮ ਅਤੇ ਕੀਮਤਾਂ ਜਾਂਚੋ।',
      'saleSaved':
          'ਤੁਹਾਡੀ ਵਿਕਰੀ ਸੇਵ ਹੋ ਗਈ ਹੈ। ਤੁਸੀਂ ਅਗਲੀ ਵਿਕਰੀ ਸ਼ੁਰੂ ਕਰ ਸਕਦੇ ਹੋ ਜਾਂ ਸੇਵ ਕੀਤੀ ਲੈਣ-ਦੇਣ ਦੇਖਣ ਲਈ Bills ਖੋਲ੍ਹ ਸਕਦੇ ਹੋ।',
    },
    'bn': {
      'languageSelection':
          'Retail Mind-এ স্বাগতম। যে ভাষাটি আপনার সবচেয়ে ভালো বোঝা হয় সেটি বেছে Continue চাপুন। পরে Settings থেকে ভাষা বদলাতে পারবেন।',
      'login':
          'আপনার ব্যবহারকারীর নাম বা ইমেইল ও পাসওয়ার্ড লিখে Sign In চাপুন। অ্যাকাউন্ট না থাকলে Register চাপুন।',
      'register':
          'আপনার ব্যবহারকারীর নাম, ইমেইল, পাসওয়ার্ড এবং দোকান থাকলে তার নাম লিখে Register চাপুন। পাসওয়ার্ড গোপন রাখুন।',
      'afterLogin':
          'আপনি সাইন ইন করেছেন। Add Sale খুলুন। পণ্য ও পরিমাণ বেছে নিন, মোট টাকা দেখুন এবং পেমেন্টের পদ্ধতি নির্বাচন করুন। টাকা পাওয়ার পরেই পেমেন্ট নিশ্চিত করুন। তারপর Save Sales চাপুন। আবার শুনতে স্পিকার বোতাম চাপুন।',
      'sale':
          'বিক্রি নথিভুক্ত করতে বিলে পণ্য বেছে পরিমাণ লিখুন। প্রতিটি পণ্যের জন্য এটি করুন। মোট টাকা দেখুন, Cash বা U P I বেছে নিন এবং টাকা পাওয়ার পরেই নিশ্চিত করে Save Sales চাপুন। ইন্টারনেট না থাকলে বিক্রি সিঙ্কের জন্য সারিতে থাকবে।',
      'inventoryPhoto':
          'Inventory-তে পণ্যের ছবি তুলতে Take Photo চাপুন, অথবা আগের ছবি বেছে নিতে Choose Photo চাপুন। Add Product চাপার আগে নাম ও দাম পরীক্ষা করুন।',
      'saleSaved':
          'আপনার বিক্রি সংরক্ষিত হয়েছে। আরেকটি বিক্রি শুরু করুন অথবা সংরক্ষিত লেনদেন দেখতে Bills খুলুন।',
    },
  };

  static const Map<String, Map<String, String>> _screenGuides = {
    'guidanceChoice': {
      'en':
          'Choose whether you can use the app on your own or need step-by-step guidance. Then tap Continue. If you need guidance, the app will speak instructions for each screen.',
      'te':
          'మీరు యాప్‌ను స్వయంగా ఉపయోగించగలరా లేదా ప్రతి దశలో సూచనలు కావాలా ఎంచుకోండి. తర్వాత Continue నొక్కండి. సూచనలు కావాలని ఎంచుకుంటే, ప్రతి పేజీకి అవసరమైన మార్గదర్శకం వినిపిస్తుంది.',
      'hi':
          'चुनें कि आप ऐप अपने आप चला सकते हैं या आपको हर कदम पर निर्देश चाहिए। फिर Continue दबाएँ। निर्देश चुनने पर हर पेज के लिए मार्गदर्शन सुनाई देगा।',
      'ta':
          'செயலியை நீங்களே பயன்படுத்துவீர்களா அல்லது ஒவ்வொரு படியிலும் வழிகாட்டுதல் வேண்டுமா என்பதைத் தேர்ந்தெடுத்து Continue-ஐத் தட்டவும். வழிகாட்டுதலைத் தேர்ந்தெடுத்தால் ஒவ்வொரு பக்கத்திற்கும் அறிவுறுத்தல்கள் ஒலிக்கும்.',
      'kn':
          'ನೀವು ಆ್ಯಪ್ ಅನ್ನು ಸ್ವತಃ ಬಳಸಬಹುದೇ ಅಥವಾ ಹಂತ ಹಂತದ ಮಾರ್ಗದರ್ಶನ ಬೇಕೇ ಎಂದು ಆಯ್ಕೆಮಾಡಿ. ನಂತರ Continue ಒತ್ತಿ. ಮಾರ್ಗದರ್ಶನ ಆಯ್ಕೆ ಮಾಡಿದರೆ ಪ್ರತಿ ಪುಟದ ಸೂಚನೆಗಳು ಕೇಳಿಸುತ್ತವೆ.',
      'ml':
          'ആപ്പ് സ്വയം ഉപയോഗിക്കാമോ അതോ ഓരോ ഘട്ടത്തിലും നിർദ്ദേശങ്ങൾ വേണോ എന്ന് തിരഞ്ഞെടുത്ത് Continue അമർത്തുക. നിർദ്ദേശങ്ങൾ തിരഞ്ഞെടുത്താൽ ഓരോ പേജിനും മാർഗ്ഗനിർദ്ദേശം കേൾക്കാം.',
      'mr':
          'तुम्ही अॅप स्वतः वापरू शकता की प्रत्येक टप्प्यावर मार्गदर्शन हवे आहे ते निवडा. मग Continue दाबा. मार्गदर्शन निवडल्यास प्रत्येक पानासाठी सूचना ऐकू येतील.',
      'gu':
          'તમે એપ જાતે વાપરી શકો છો કે દરેક પગલે માર્ગદર્શન જોઈએ છે તે પસંદ કરો. પછી Continue દબાવો. માર્ગદર્શન પસંદ કરશો તો દરેક પેજ માટે સૂચનાઓ સંભળાશે.',
      'pa':
          'ਚੁਣੋ ਕਿ ਤੁਸੀਂ ਐਪ ਆਪਣੇ ਆਪ ਵਰਤ ਸਕਦੇ ਹੋ ਜਾਂ ਤੁਹਾਨੂੰ ਹਰ ਕਦਮ ਲਈ ਸੇਧ ਚਾਹੀਦੀ ਹੈ। ਫਿਰ Continue ਦਬਾਓ। ਸੇਧ ਚੁਣਨ ਤੇ ਹਰ ਪੰਨੇ ਲਈ ਹਦਾਇਤਾਂ ਸੁਣਾਈ ਦੇਣਗੀਆਂ।',
      'bn':
          'বেছে নিন আপনি নিজে অ্যাপ ব্যবহার করবেন, নাকি প্রতিটি ধাপে নির্দেশনা চান। তারপর Continue চাপুন। নির্দেশনা বেছে নিলে প্রতিটি পাতার জন্য নির্দেশনা শোনা যাবে।',
    },
    'languageSelection': {
      'en': 'Choose your language, then tap Continue.',
      'hi': 'अपनी भाषा चुनें, फिर Continue दबाएँ।',
      'te': 'మీ భాషను ఎంచుకుని Continue నొక్కండి.',
      'ta': 'உங்கள் மொழியைத் தேர்ந்தெடுத்து Continue-ஐத் தட்டவும்.',
      'kn': 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆ ಮಾಡಿ, ನಂತರ Continue ಒತ್ತಿ.',
      'ml': 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കി Continue ടാപ്പ് ചെയ്യുക.',
      'mr': 'तुमची भाषा निवडा आणि Continue दाबा.',
      'gu': 'તમારી ભાષા પસંદ કરો અને Continue દબાવો.',
      'pa': 'ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ, ਫਿਰ Continue ਦਬਾਓ।',
      'bn': 'আপনার ভাষা বেছে নিন, তারপর Continue চাপুন।',
    },
    'login': {
      'en':
          'Enter your username or email and password, then tap Sign In. If you do not have an account, tap Register.',
      'hi':
          'अपना यूज़रनेम या ईमेल और पासवर्ड भरें, फिर Sign In दबाएँ। खाता नहीं है तो Register दबाएँ।',
      'te':
          'మీ యూజర్ పేరు లేదా ఇమెయిల్, పాస్‌వర్డ్ నమోదు చేసి Sign In నొక్కండి. ఖాతా లేకపోతే Register నొక్కండి.',
      'ta':
          'உங்கள் பயனர்பெயர் அல்லது மின்னஞ்சல் மற்றும் கடவுச்சொல்லை உள்ளிட்டு Sign In-ஐத் தட்டவும். கணக்கு இல்லையெனில் Register-ஐத் தட்டவும்.',
      'kn':
          'ನಿಮ್ಮ ಬಳಕೆದಾರ ಹೆಸರು ಅಥವಾ ಇಮೇಲ್ ಮತ್ತು ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ Sign In ಒತ್ತಿ. ಖಾತೆ ಇಲ್ಲದಿದ್ದರೆ Register ಒತ್ತಿ.',
      'ml':
          'നിങ്ങളുടെ ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഇമെയിലും പാസ്‌വേഡും നൽകി Sign In അമർത്തുക. അക്കൗണ്ട് ഇല്ലെങ്കിൽ Register അമർത്തുക.',
      'mr':
          'तुमचे वापरकर्तानाव किंवा ईमेल आणि पासवर्ड भरा, नंतर Sign In दाबा. खाते नसेल तर Register दाबा.',
      'gu':
          'તમારું વપરાશકર્તા નામ અથવા ઇમેઇલ અને પાસવર્ડ દાખલ કરો, પછી Sign In દબાવો. ખાતું ન હોય તો Register દબાવો.',
      'pa':
          'ਆਪਣਾ ਯੂਜ਼ਰਨੇਮ ਜਾਂ ਈਮੇਲ ਅਤੇ ਪਾਸਵਰਡ ਦਰਜ ਕਰੋ, ਫਿਰ Sign In ਦਬਾਓ। ਖਾਤਾ ਨਹੀਂ ਹੈ ਤਾਂ Register ਦਬਾਓ।',
      'bn':
          'আপনার ব্যবহারকারীর নাম বা ইমেইল ও পাসওয়ার্ড লিখে Sign In চাপুন। অ্যাকাউন্ট না থাকলে Register চাপুন।',
    },
    'register': {
      'en':
          'Enter your username, shop name if you have one, email, and password. Then tap Register.',
      'hi':
          'अपना यूज़रनेम, दुकान का नाम यदि हो, ईमेल और पासवर्ड भरें। फिर Register दबाएँ।',
      'te':
          'మీ యూజర్ పేరు, ఉంటే దుకాణం పేరు, ఇమెయిల్, పాస్‌వర్డ్ నమోదు చేసి Register నొక్కండి.',
      'ta':
          'உங்கள் பயனர்பெயர், இருந்தால் கடையின் பெயர், மின்னஞ்சல் மற்றும் கடவுச்சொல்லை உள்ளிட்டு Register-ஐத் தட்டவும்.',
      'kn':
          'ನಿಮ್ಮ ಬಳಕೆದಾರ ಹೆಸರು, ಇದ್ದರೆ ಅಂಗಡಿ ಹೆಸರು, ಇಮೇಲ್ ಮತ್ತು ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ Register ಒತ್ತಿ.',
      'ml':
          'നിങ്ങളുടെ ഉപയോക്തൃനാമം, ഉണ്ടെങ്കിൽ കടയുടെ പേര്, ഇമെയിൽ, പാസ്‌വേഡ് എന്നിവ നൽകി Register അമർത്തുക.',
      'mr':
          'तुमचे वापरकर्तानाव, असल्यास दुकानाचे नाव, ईमेल आणि पासवर्ड भरा. नंतर Register दाबा.',
      'gu':
          'તમારું વપરાશકર્તા નામ, દુકાનનું નામ હોય તો તે, ઇમેઇલ અને પાસવર્ડ દાખલ કરીને Register દબાવો.',
      'pa':
          'ਆਪਣਾ ਯੂਜ਼ਰਨੇਮ, ਜੇ ਦੁਕਾਨ ਹੈ ਤਾਂ ਉਸਦਾ ਨਾਮ, ਈਮੇਲ ਅਤੇ ਪਾਸਵਰਡ ਦਰਜ ਕਰੋ। ਫਿਰ Register ਦਬਾਓ।',
      'bn':
          'আপনার ব্যবহারকারীর নাম, দোকান থাকলে দোকানের নাম, ইমেইল ও পাসওয়ার্ড লিখে Register চাপুন।',
    },
    'roleSelection': {
      'en':
          'Choose Owner if you own this shop. We will send a six-digit verification code to your email. Choose Staff or Worker to sign in with your staff PIN.',
      'hi':
          'दुकान आपकी है तो Owner चुनें। आपके ईमेल पर छह अंकों का सत्यापन कोड भेजा जाएगा। Staff या Worker चुनने पर अपना स्टाफ PIN डालें।',
      'te':
          'ఈ దుకాణం మీదైతే Owner ఎంచుకోండి. మీ ఇమెయిల్‌కు ఆరు అంకెల నిర్ధారణ కోడ్ పంపుతాము. Staff లేదా Worker ఎంచుకుంటే మీ స్టాఫ్ PIN నమోదు చేయండి.',
      'ta':
          'இந்தக் கடை உங்களுடையது என்றால் Owner-ஐத் தேர்ந்தெடுக்கவும். உங்கள் மின்னஞ்சலுக்கு ஆறு இலக்கச் சரிபார்ப்புக் குறியீடு அனுப்பப்படும். Staff அல்லது Worker-ஐத் தேர்ந்தெடுத்தால் உங்கள் பணியாளர் PIN-ஐ உள்ளிடவும்.',
      'kn':
          'ಈ ಅಂಗಡಿ ನಿಮ್ಮದಾದರೆ Owner ಆಯ್ಕೆಮಾಡಿ. ನಿಮ್ಮ ಇಮೇಲ್‌ಗೆ ಆರು ಅಂಕಿಯ ಪರಿಶೀಲನಾ ಕೋಡ್ ಕಳುಹಿಸುತ್ತೇವೆ. Staff ಅಥವಾ Worker ಆಯ್ಕೆ ಮಾಡಿದರೆ ನಿಮ್ಮ ಸಿಬ್ಬಂದಿ PIN ನಮೂದಿಸಿ.',
      'ml':
          'ഈ കട നിങ്ങളുടേതാണെങ്കിൽ Owner തിരഞ്ഞെടുക്കുക. നിങ്ങളുടെ ഇമെയിലിലേക്ക് ആറക്ക പരിശോധനാ കോഡ് അയക്കും. Staff അല്ലെങ്കിൽ Worker തിരഞ്ഞെടുത്താൽ നിങ്ങളുടെ സ്റ്റാഫ് PIN നൽകുക.',
      'mr':
          'दुकान तुमचे असल्यास Owner निवडा. तुमच्या ईमेलवर सहा अंकी पडताळणी कोड पाठवू. Staff किंवा Worker निवडल्यास तुमचा स्टाफ PIN भरा.',
      'gu':
          'આ દુકાન તમારી હોય તો Owner પસંદ કરો. તમારા ઇમેઇલ પર છ અંકનો ચકાસણી કોડ મોકલીશું. Staff અથવા Worker પસંદ કરો તો તમારો સ્ટાફ PIN દાખલ કરો.',
      'pa':
          'ਜੇ ਇਹ ਦੁਕਾਨ ਤੁਹਾਡੀ ਹੈ ਤਾਂ Owner ਚੁਣੋ। ਤੁਹਾਡੇ ਈਮੇਲ ਉੱਤੇ ਛੇ ਅੰਕਾਂ ਦਾ ਤਸਦੀਕੀ ਕੋਡ ਭੇਜਾਂਗੇ। Staff ਜਾਂ Worker ਚੁਣੋ ਤਾਂ ਆਪਣਾ ਸਟਾਫ PIN ਦਰਜ ਕਰੋ।',
      'bn':
          'দোকানটি আপনার হলে Owner বেছে নিন। আপনার ইমেইলে ছয় অঙ্কের যাচাইকরণ কোড পাঠানো হবে। Staff বা Worker বেছে নিলে আপনার স্টাফ PIN লিখুন।',
    },
    'ownerOtp': {
      'en':
          'Enter the six-digit verification code sent to your email, then tap Verify PIN.',
      'hi':
          'आपके ईमेल पर भेजा गया छह अंकों का सत्यापन कोड भरें, फिर Verify PIN दबाएँ।',
      'te':
          'మీ ఇమెయిల్‌కు పంపిన ఆరు అంకెల నిర్ధారణ కోడ్ నమోదు చేసి Verify PIN నొక్కండి.',
      'ta':
          'உங்கள் மின்னஞ்சலுக்கு அனுப்பிய ஆறு இலக்கச் சரிபார்ப்புக் குறியீட்டை உள்ளிட்டு Verify PIN-ஐத் தட்டவும்.',
      'kn':
          'ನಿಮ್ಮ ಇಮೇಲ್‌ಗೆ ಕಳುಹಿಸಿದ ಆರು ಅಂಕಿಯ ಪರಿಶೀಲನಾ ಕೋಡ್ ನಮೂದಿಸಿ Verify PIN ಒತ್ತಿ.',
      'ml':
          'നിങ്ങളുടെ ഇമെയിലിലേക്ക് അയച്ച ആറക്ക പരിശോധനാ കോഡ് നൽകി Verify PIN അമർത്തുക.',
      'mr':
          'तुमच्या ईमेलवर पाठवलेला सहा अंकी पडताळणी कोड भरा आणि Verify PIN दाबा.',
      'gu':
          'તમારા ઇમેઇલ પર મોકલેલો છ અંકનો ચકાસણી કોડ દાખલ કરીને Verify PIN દબાવો.',
      'pa':
          'ਆਪਣੇ ਈਮੇਲ ਉੱਤੇ ਭੇਜਿਆ ਛੇ ਅੰਕਾਂ ਦਾ ਤਸਦੀਕੀ ਕੋਡ ਦਰਜ ਕਰੋ ਅਤੇ Verify PIN ਦਬਾਓ।',
      'bn':
          'আপনার ইমেইলে পাঠানো ছয় অঙ্কের যাচাইকরণ কোড লিখে Verify PIN চাপুন।',
    },
    'usernameField': {
      'en': 'Enter your username or email address.',
      'te': 'మీ యూజర్ పేరు లేదా ఇమెయిల్ చిరునామా నమోదు చేయండి.',
      'hi': 'अपना यूज़रनेम या ईमेल पता भरें।',
      'ta': 'உங்கள் பயனர்பெயர் அல்லது மின்னஞ்சல் முகவரியை உள்ளிடவும்.',
      'kn': 'ನಿಮ್ಮ ಬಳಕೆದಾರ ಹೆಸರು ಅಥವಾ ಇಮೇಲ್ ವಿಳಾಸ ನಮೂದಿಸಿ.',
      'ml': 'നിങ്ങളുടെ ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഇമെയിൽ വിലാസം നൽകുക.',
      'mr': 'तुमचे वापरकर्तानाव किंवा ईमेल पत्ता भरा.',
      'gu': 'તમારું વપરાશકર્તા નામ અથવા ઇમેઇલ સરનામું દાખલ કરો.',
      'pa': 'ਆਪਣਾ ਯੂਜ਼ਰਨੇਮ ਜਾਂ ਈਮੇਲ ਪਤਾ ਦਰਜ ਕਰੋ।',
      'bn': 'আপনার ব্যবহারকারীর নাম বা ইমেইল ঠিকানা লিখুন।',
    },
    'emailField': {
      'en': 'Enter your email address.',
      'te': 'మీ ఇమెయిల్ చిరునామా నమోదు చేయండి.',
      'hi': 'अपना ईमेल पता भरें।',
      'ta': 'உங்கள் மின்னஞ்சல் முகவரியை உள்ளிடவும்.',
      'kn': 'ನಿಮ್ಮ ಇಮೇಲ್ ವಿಳಾಸ ನಮೂದಿಸಿ.',
      'ml': 'നിങ്ങളുടെ ഇമെയിൽ വിലാസം നൽകുക.',
      'mr': 'तुमचा ईमेल पत्ता भरा.',
      'gu': 'તમારું ઇમેઇલ સરનામું દાખલ કરો.',
      'pa': 'ਆਪਣਾ ਈਮੇਲ ਪਤਾ ਦਰਜ ਕਰੋ।',
      'bn': 'আপনার ইমেইল ঠিকানা লিখুন।',
    },
    'passwordField': {
      'en': 'Enter your password. Keep it private.',
      'te': 'మీ పాస్‌వర్డ్ నమోదు చేయండి. దానిని రహస్యంగా ఉంచండి.',
      'hi': 'अपना पासवर्ड भरें। इसे गुप्त रखें।',
      'ta': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும். அதை ரகசியமாக வைத்திருக்கவும்.',
      'kn': 'ನಿಮ್ಮ ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ. ಅದನ್ನು ಗೌಪ್ಯವಾಗಿಡಿ.',
      'ml': 'നിങ്ങളുടെ പാസ്‌വേഡ് നൽകുക. അത് രഹസ്യമായി സൂക്ഷിക്കുക.',
      'mr': 'तुमचा पासवर्ड भरा. तो गुप्त ठेवा.',
      'gu': 'તમારો પાસવર્ડ દાખલ કરો. તેને ગુપ્ત રાખો.',
      'pa': 'ਆਪਣਾ ਪਾਸਵਰਡ ਦਰਜ ਕਰੋ। ਇਸਨੂੰ ਗੁਪਤ ਰੱਖੋ।',
      'bn': 'আপনার পাসওয়ার্ড লিখুন। এটি গোপন রাখুন।',
    },
    'shopNameField': {
      'en': 'Enter your shop name if you have one. This is optional.',
      'te': 'మీకు దుకాణం ఉంటే దాని పేరు నమోదు చేయండి. ఇది ఐచ్ఛికం.',
      'hi': 'दुकान हो तो उसका नाम भरें। यह वैकल्पिक है।',
      'ta': 'கடை இருந்தால் அதன் பெயரை உள்ளிடவும். இது விருப்பமானது.',
      'kn': 'ಅಂಗಡಿ ಇದ್ದರೆ ಅದರ ಹೆಸರನ್ನು ನಮೂದಿಸಿ. ಇದು ಐಚ್ಛಿಕ.',
      'ml': 'കടയുണ്ടെങ്കിൽ അതിന്റെ പേര് നൽകുക. ഇത് ഐച്ഛികമാണ്.',
      'mr': 'दुकान असल्यास तिचे नाव भरा. हे ऐच्छिक आहे.',
      'gu': 'દુકાન હોય તો તેનું નામ દાખલ કરો. આ વૈકલ્પિક છે.',
      'pa': 'ਜੇ ਦੁਕਾਨ ਹੈ ਤਾਂ ਉਸਦਾ ਨਾਮ ਦਰਜ ਕਰੋ। ਇਹ ਲਾਜ਼ਮੀ ਨਹੀਂ ਹੈ।',
      'bn': 'দোকান থাকলে তার নাম লিখুন। এটি ঐচ্ছিক।',
    },
    'staffPinField': {
      'en': 'Enter your four-digit staff PIN.',
      'te': 'మీ నాలుగు అంకెల స్టాఫ్ PIN నమోదు చేయండి.',
      'hi': 'अपना चार अंकों का स्टाफ PIN भरें।',
      'ta': 'உங்கள் நான்கு இலக்கப் பணியாளர் PIN-ஐ உள்ளிடவும்.',
      'kn': 'ನಿಮ್ಮ ನಾಲ್ಕು ಅಂಕಿಯ ಸಿಬ್ಬಂದಿ PIN ನಮೂದಿಸಿ.',
      'ml': 'നിങ്ങളുടെ നാലക്ക സ്റ്റാഫ് PIN നൽകുക.',
      'mr': 'तुमचा चार अंकी स्टाफ PIN भरा.',
      'gu': 'તમારો ચાર અંકનો સ્ટાફ PIN દાખલ કરો.',
      'pa': 'ਆਪਣਾ ਚਾਰ ਅੰਕਾਂ ਦਾ ਸਟਾਫ PIN ਦਰਜ ਕਰੋ।',
      'bn': 'আপনার চার অঙ্কের স্টাফ PIN লিখুন।',
    },
    'otpField': {
      'en': 'Enter the six-digit code sent to your email.',
      'te': 'మీ ఇమెయిల్‌కు పంపిన ఆరు అంకెల కోడ్ నమోదు చేయండి.',
      'hi': 'आपके ईमेल पर भेजा गया छह अंकों का कोड भरें।',
      'ta': 'உங்கள் மின்னஞ்சலுக்கு அனுப்பிய ஆறு இலக்கக் குறியீட்டை உள்ளிடவும்.',
      'kn': 'ನಿಮ್ಮ ಇಮೇಲ್‌ಗೆ ಕಳುಹಿಸಿದ ಆರು ಅಂಕಿಯ ಕೋಡ್ ನಮೂದಿಸಿ.',
      'ml': 'നിങ്ങളുടെ ഇമെയിലിലേക്ക് അയച്ച ആറക്ക കോഡ് നൽകുക.',
      'mr': 'तुमच्या ईमेलवर पाठवलेला सहा अंकी कोड भरा.',
      'gu': 'તમારા ઇમેઇલ પર મોકલેલો છ અંકનો કોડ દાખલ કરો.',
      'pa': 'ਆਪਣੇ ਈਮੇਲ ਉੱਤੇ ਭੇਜਿਆ ਛੇ ਅੰਕਾਂ ਦਾ ਕੋਡ ਦਰਜ ਕਰੋ।',
      'bn': 'আপনার ইমেইলে পাঠানো ছয় অঙ্কের কোড লিখুন।',
    },
    'inputField': {
      'en': 'Enter the information requested in this field.',
      'te': 'ఈ ఖాళీలో అడిగిన వివరాలను నమోదు చేయండి.',
      'hi': 'इस खाने में मांगी गई जानकारी भरें।',
      'ta': 'இந்தப் புலத்தில் கேட்கப்பட்ட தகவலை உள்ளிடவும்.',
      'kn': 'ಈ ಜಾಗದಲ್ಲಿ ಕೇಳಿರುವ ಮಾಹಿತಿಯನ್ನು ನಮೂದಿಸಿ.',
      'ml': 'ഈ ഫീൽഡിൽ ആവശ്യപ്പെട്ട വിവരം നൽകുക.',
      'mr': 'या जागेत मागितलेली माहिती भरा.',
      'gu': 'આ જગ્યામાં પૂછેલી માહિતી દાખલ કરો.',
      'pa': 'ਇਸ ਖਾਨੇ ਵਿੱਚ ਮੰਗੀ ਜਾਣਕਾਰੀ ਦਰਜ ਕਰੋ।',
      'bn': 'এই ঘরে চাওয়া তথ্য লিখুন।',
    },
  };

  /// Exposed as a pure function so supported prompts can be tested without
  /// initializing a platform TTS engine.
  static String instructionFor(String step, String languageCode) {
    final language = _normalizeLanguageCode(languageCode);
    return _copy[language]?[step] ??
        _screenGuides[step]?[language] ??
        _copy['en']?[step] ??
        _screenGuides[step]?['en'] ??
        '';
  }

  static String instructionForScreenGuide(String step, String languageCode) {
    final language = _normalizeLanguageCode(languageCode);
    return _screenGuides[step]?[language] ?? _copy[language]?[step] ?? '';
  }

  static String _normalizeLanguageCode(String languageCode) {
    final normalized = languageCode.toLowerCase().replaceAll('_', '-');
    final baseCode = normalized.split('-').first;
    return _localeByLanguage.containsKey(baseCode) ? baseCode : 'en';
  }

  Future<void> speakScreenGuide(String step, String languageCode) async {
    final localized = instructionForScreenGuide(step, languageCode);
    if (localized.isEmpty) return;
    await _speakText(localized, languageCode);
  }

  Future<void> _speakText(String text, String languageCode) async {
    final normalizedCode = _normalizeLanguageCode(languageCode);
    final requestedLocale = localeForLanguageCode(normalizedCode)!;
    final requestVersion = ++_requestVersion;
    final wasSpeaking = _isSpeaking;
    _isStarting = true;
    _isSpeaking = false;
    notifyListeners();

    try {
      if (wasSpeaking) await _tts.stop();
      if (requestVersion != _requestVersion) return;
      _isSpeaking = false;
      await (_engineSetup ??= _configureEngine());
      if (requestVersion != _requestVersion) return;

      final selectedLocale = await _configureLocale(
        requestedLocale: requestedLocale,
        languageCode: normalizedCode,
      );
      if (requestVersion != _requestVersion) return;
      if (selectedLocale == null) {
        debugPrint(
          'TTS voice for $normalizedCode is unavailable; skipping speech '
          'instead of speaking in another language.',
        );
        _finishRequest(requestVersion);
        return;
      }
      final languageResult = await _tts.setLanguage(selectedLocale);
      if (languageResult != 1 && languageResult != true) {
        _localeTasks.remove(normalizedCode);
        throw StateError('TTS could not select $selectedLocale');
      }
      if (requestVersion != _requestVersion) return;
      _isSpeaking = true;
      _isStarting = false;
      notifyListeners();
      await _tts.speak(text);
    } catch (error) {
      debugPrint('Could not speak $normalizedCode guidance: $error');
      if (requestVersion == _requestVersion) {
        _localeTasks.remove(normalizedCode);
        _engineSetup = null;
        _finishRequest(requestVersion);
        try {
          await _tts.stop();
        } catch (stopError) {
          debugPrint('Could not stop unavailable TTS voice: $stopError');
        }
      }
    }
  }

  Future<void> _configureEngine() async {
    await _tts.awaitSpeakCompletion(false);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  void _finishRequest(int requestVersion) {
    if (requestVersion != _requestVersion) return;
    _isStarting = false;
    _isSpeaking = false;
    notifyListeners();
  }

  Future<String?> _configureLocale({
    required String requestedLocale,
    required String languageCode,
  }) async {
    final task = _localeTasks.putIfAbsent(languageCode, () async {
      final rawLanguages = await _tts.getLanguages;
      final available = rawLanguages is List
          ? rawLanguages.map((value) => value.toString()).toList()
          : <String>[];
      final selectedLocale = available.isEmpty
          ? requestedLocale
          : _matchAvailableLocale(available, requestedLocale, languageCode);
      if (selectedLocale == null) return null;

      final localeAvailable = await _tts.isLanguageAvailable(selectedLocale);
      if (localeAvailable != true) return null;
      return selectedLocale;
    });
    try {
      final locale = await task;
      if (locale == null) _localeTasks.remove(languageCode);
      return locale;
    } catch (_) {
      _localeTasks.remove(languageCode);
      rethrow;
    }
  }

  Future<void> speakStep(String step, String languageCode) async {
    final localized = instructionForScreenGuide(step, languageCode);
    if (localized.isEmpty) return;
    await _speakText(localized, languageCode);
  }

  Future<void> speakStepIfGuided(String step, String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(guidedModePreferenceKey) ?? false) {
        await speakStep(step, languageCode);
      }
    } catch (error) {
      debugPrint('Unable to load guided voice preference: $error');
    }
  }

  String? _matchAvailableLocale(
    List<String> available,
    String requested,
    String languageCode,
  ) {
    final normalizedRequested = requested.toLowerCase().replaceAll('_', '-');
    for (final item in available) {
      if (item.toLowerCase().replaceAll('_', '-') == normalizedRequested) {
        return item;
      }
    }
    for (final item in available) {
      final normalized = item.toLowerCase().replaceAll('_', '-');
      if (normalized == languageCode ||
          normalized.startsWith('$languageCode-')) {
        return item;
      }
    }
    return null;
  }

  Future<void> stop() async {
    _requestVersion++;
    _isStarting = false;
    _isSpeaking = false;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {
      // Speech is optional; stopping it must never block the workflow.
    } finally {
      _updatePlaybackState(speaking: false);
    }
  }
}
