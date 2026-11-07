// =============================================================================
// voice_billing_display.dart
//
// DISPLAY-ONLY localisation for voice billing and sales entry.
//
//   The English / catalogue product name is what gets SAVED and what stock is
//   deducted by. This file only decides what the shopkeeper SEES. Nothing here
//   may ever be written back into a ParsedItem, a controller that feeds the
//   bill, or the database.
//
// Everything is offline and deterministic, so it works instantly on low-end
// phones and without network. Callers should try this first and only fall back
// to the network translator (LiveTranslatedText) when a function returns null.
//
// Pure Dart. Phrases below should be reviewed by a native speaker of each
// language before release.
// =============================================================================

class VoiceBillingDisplay {
  VoiceBillingDisplay._();

  static const List<String> _langs = [
    'te', 'hi', 'ta', 'kn', 'ml', 'mr', 'bn', 'gu', 'pa',
  ];

  static String _base(String languageCode) =>
      languageCode.trim().toLowerCase().split(RegExp(r'[-_]')).first;

  // ───────────────────────────────────────────────────────────────────────────
  // Product names
  // ───────────────────────────────────────────────────────────────────────────

  /// Order: te, hi, ta, kn, ml, mr, bn, gu, pa.
  static const Map<String, List<String>> _products = {
    'chicken': ['చికెన్', 'चिकन', 'சிக்கன்', 'ಚಿಕನ್', 'ചിക്കൻ', 'चिकन', 'চিকেন', 'ચિકન', 'ਚਿਕਨ'],
    'mutton': ['మటన్', 'मटन', 'மட்டன்', 'ಮಟನ್', 'മട്ടൺ', 'मटण', 'মটন', 'મટન', 'ਮਟਨ'],
    'fish': ['చేప', 'मछली', 'மீன்', 'ಮೀನು', 'മീൻ', 'मासा', 'মাছ', 'માછલી', 'ਮੱਛੀ'],
    'egg': ['గుడ్డు', 'अंडा', 'முட்டை', 'ಮೊಟ್ಟೆ', 'മുട്ട', 'अंडे', 'ডিম', 'ઈંડું', 'ਆਂਡਾ'],
    'biryani': ['బిర్యానీ', 'बिरयानी', 'பிரியாணி', 'ಬಿರಿಯಾನಿ', 'ബിരിയാണി', 'बिर्याणी', 'বিরিয়ানি', 'બિરયાની', 'ਬਿਰਯਾਨੀ'],
    'rice': ['బియ్యం', 'चावल', 'அரிசி', 'ಅಕ್ಕಿ', 'അരി', 'तांदूळ', 'চাল', 'ચોખા', 'ਚੌਲ'],
    'sugar': ['చక్కెర', 'चीनी', 'சர்க்கரை', 'ಸಕ್ಕರೆ', 'പഞ്ചസാര', 'साखर', 'চিনি', 'ખાંડ', 'ਖੰਡ'],
    'salt': ['ఉప్పు', 'नमक', 'உப்பு', 'ಉಪ್ಪು', 'ഉപ്പ്', 'मीठ', 'নুন', 'મીઠું', 'ਲੂਣ'],
    'oil': ['నూనె', 'तेल', 'எண்ணெய்', 'ಎಣ್ಣೆ', 'എണ്ണ', 'तेल', 'তেল', 'તેલ', 'ਤੇਲ'],
    'milk': ['పాలు', 'दूध', 'பால்', 'ಹಾಲು', 'പാൽ', 'दूध', 'দুধ', 'દૂધ', 'ਦੁੱਧ'],
    'curd': ['పెరుగు', 'दही', 'தயிர்', 'ಮೊಸರು', 'തൈര്', 'दही', 'দই', 'દહીં', 'ਦਹੀਂ'],
    'tea': ['టీ', 'चाय', 'தேநீர்', 'ಚಹಾ', 'ചായ', 'चहा', 'চা', 'ચા', 'ਚਾਹ'],
    'coffee': ['కాఫీ', 'कॉफ़ी', 'காபி', 'ಕಾಫಿ', 'കാപ്പി', 'कॉफी', 'কফি', 'કોફી', 'ਕੌਫੀ'],
    'wheat': ['గోధుమ', 'गेहूं', 'கோதுமை', 'ಗೋಧಿ', 'ഗോതമ്പ്', 'गहू', 'গম', 'ઘઉં', 'ਕਣਕ'],
    'flour': ['పిండి', 'आटा', 'மாவு', 'ಹಿಟ್ಟು', 'മാവ്', 'पीठ', 'আটা', 'લોટ', 'ਆਟਾ'],
    'dal': ['పప్పు', 'दाल', 'பருப்பு', 'ಬೇಳೆ', 'പരിപ്പ്', 'डाळ', 'ডাল', 'દાળ', 'ਦਾਲ'],
    'onion': ['ఉల్లిపాయ', 'प्याज़', 'வெங்காயம்', 'ಈರುಳ್ಳಿ', 'ഉള്ളി', 'कांदा', 'পেঁয়াজ', 'ડુંગળી', 'ਪਿਆਜ਼'],
    'potato': ['బంగాళాదుంప', 'आलू', 'உருளைக்கிழங்கு', 'ಆಲೂಗಡ್ಡೆ', 'ഉരുളക്കിഴങ്ങ്', 'बटाटा', 'আলু', 'બટાકા', 'ਆਲੂ'],
    'tomato': ['టమాటా', 'टमाटर', 'தக்காளி', 'ಟೊಮೇಟೊ', 'തക്കാളി', 'टोमॅटो', 'টমেটো', 'ટામેટા', 'ਟਮਾਟਰ'],
    'ghee': ['నెయ్యి', 'घी', 'நெய்', 'ತುಪ್ಪ', 'നെയ്യ്', 'तूप', 'ঘি', 'ઘી', 'ਘਿਓ'],
    'butter': ['వెన్న', 'मक्खन', 'வெண்ணெய்', 'ಬೆಣ್ಣೆ', 'വെണ്ണ', 'लोणी', 'মাখন', 'માખણ', 'ਮੱਖਣ'],
    'bread': ['బ్రెడ్', 'ब्रेड', 'பிரெட்', 'ಬ್ರೆಡ್', 'ബ്രെഡ്', 'ब्रेड', 'পাউরুটি', 'બ્રેડ', 'ਬ੍ਰੈੱਡ'],
    'biscuit': ['బిస్కెట్', 'बिस्किट', 'பிஸ்கட்', 'ಬಿಸ್ಕತ್ತು', 'ബിസ്കറ്റ്', 'बिस्किट', 'বিস্কুট', 'બિસ્કિટ', 'ਬਿਸਕੁਟ'],
    'soap': ['సబ్బు', 'साबुन', 'சோப்பு', 'ಸೋಪು', 'സോപ്പ്', 'साबण', 'সাবান', 'સાબુ', 'ਸਾਬਣ'],
    'water': ['నీళ్లు', 'पानी', 'தண்ணீர்', 'ನೀರು', 'വെള്ളം', 'पाणी', 'জল', 'પાણી', 'ਪਾਣੀ'],
    'juice': ['జ్యూస్', 'जूस', 'ஜூஸ்', 'ಜ್ಯೂಸ್', 'ജ്യൂസ്', 'ज्यूस', 'জুস', 'જ્યુસ', 'ਜੂਸ'],
    'paneer': ['పనీర్', 'पनीर', 'பனீர்', 'ಪನೀರ್', 'പനീർ', 'पनीर', 'পনির', 'પનીર', 'ਪਨੀਰ'],
    'masala': ['మసాలా', 'मसाला', 'மசாலா', 'ಮಸಾಲೆ', 'മസാല', 'मसाला', 'মশলা', 'મસાલો', 'ਮਸਾਲਾ'],
    'chilli': ['మిరపకాయ', 'मिर्च', 'மிளகாய்', 'ಮೆಣಸಿನಕಾಯಿ', 'മുളക്', 'मिरची', 'লঙ্কা', 'મરચું', 'ਮਿਰਚ'],
    'turmeric': ['పసుపు', 'हल्दी', 'மஞ்சள்', 'ಅರಿಶಿನ', 'മഞ്ഞൾ', 'हळद', 'হলুদ', 'હળદર', 'ਹਲਦੀ'],
    'ginger': ['అల్లం', 'अदरक', 'இஞ்சி', 'ಶುಂಠಿ', 'ഇഞ്ചി', 'आले', 'আদা', 'આદુ', 'ਅਦਰਕ'],
    'garlic': ['వెల్లుల్లి', 'लहसुन', 'பூண்டு', 'ಬೆಳ್ಳುಳ್ಳಿ', 'വെളുത്തുള്ളി', 'लसूण', 'রসুন', 'લસણ', 'ਲਸਣ'],
    'banana': ['అరటిపండు', 'केला', 'வாழைப்பழம்', 'ಬಾಳೆಹಣ್ಣು', 'വാഴപ്പഴം', 'केळे', 'কলা', 'કેળું', 'ਕੇਲਾ'],
    'apple': ['ఆపిల్', 'सेब', 'ஆப்பிள்', 'ಸೇಬು', 'ആപ്പിൾ', 'सफरचंद', 'আপেল', 'સફરજન', 'ਸੇਬ'],
    'coconut': ['కొబ్బరి', 'नारियल', 'தேங்காய்', 'ತೆಂಗಿನಕಾಯಿ', 'തേങ്ങ', 'नारळ', 'নারকেল', 'નાળિયેર', 'ਨਾਰੀਅਲ'],
    'idli': ['ఇడ్లీ', 'इडली', 'இட்லி', 'ಇಡ್ಲಿ', 'ഇഡ്ഡലി', 'इडली', 'ইডলি', 'ઇડલી', 'ਇਡਲੀ'],
    'dosa': ['దోసె', 'डोसा', 'தோசை', 'ದೋಸೆ', 'ദോശ', 'डोसा', 'ডোসা', 'ઢોસા', 'ਡੋਸਾ'],
  };

  /// Spelling variants and plurals that appear in AI / catalogue output.
  static const Map<String, String> _aliases = {
    'eggs': 'egg',
    'biriyani': 'biryani',
    'briyani': 'biryani',
    'biryanis': 'biryani',
    'chilly': 'chilli',
    'chili': 'chilli',
    'chillies': 'chilli',
    'tomatoes': 'tomato',
    'potatoes': 'potato',
    'onions': 'onion',
    'dhal': 'dal',
    'daal': 'dal',
    'dals': 'dal',
    'biscuits': 'biscuit',
    'bananas': 'banana',
    'apples': 'apple',
    'coconuts': 'coconut',
    'idly': 'idli',
    'dosai': 'dosa',
    'atta': 'flour',
    'maida': 'flour',
    'curd': 'curd',
    'yogurt': 'curd',
    'curry': 'masala',
    'dumpa': 'potato',
    'aloo': 'potato',
    'alu': 'potato',
    'bangaladumpa': 'potato',
  };

  /// STT often returns Romanised Telugu/Hindi as a whole phrase.
  static const Map<String, String> _phraseAliases = {
    'bungalow dumpa': 'potato',
    'bangala dumpa': 'potato',
    'bangalore dumpa': 'potato',
    'bungalow potato': 'potato',
    'sunflower oil': 'oil',
  };

  static const Set<String> _skipTokens = {
    'of', 'and', 'the', 'a', 'an', 'with', 'from',
    'bungalow', 'bangala', 'bangalore',
  };

  /// Tokens that need no translation (quantities, sizes, units, joiners).
  static final RegExp _keepAsIs = RegExp(
    r'^(?:\d+(?:\.\d+)?(?:kg|g|gm|gms|l|ml|ltr|pc|pcs)?|kg|g|gm|gms|l|ml|ltr|pc|pcs|pack|of|and|&)$',
  );

  /// Localised display name for a canonical (English) product name, or null
  /// when it cannot be translated completely and reliably. Null means: use the
  /// network translator or show the original.
  ///
  /// DISPLAY ONLY: never store the result.
  static String? productName(String canonical, String languageCode) {
    final lang = _base(languageCode);
    final column = _langs.indexOf(lang);
    if (column < 0) return null;
    final trimmed = canonical.trim();
    if (trimmed.isEmpty) return null;

    final folded = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final phraseKey = _phraseAliases[folded] ?? _aliases[folded];
    if (phraseKey != null) {
      final row = _products[phraseKey];
      if (row != null) return row[column];
    }

    final tokens = folded
        .split(RegExp(r'[\s\-_/(),.]+'))
        .where((t) => t.isNotEmpty && !_skipTokens.contains(t))
        .toList();
    if (tokens.isEmpty) return null;

    final out = <String>[];
    var translated = 0;
    for (final token in tokens) {
      if (_keepAsIs.hasMatch(token)) {
        out.add(token);
        continue;
      }
      final key = _phraseAliases[token] ?? _aliases[token] ?? token;
      final row = _products[key] ?? _products[_stripPlural(key)];
      if (row != null) {
        out.add(row[column]);
        translated++;
        continue;
      }
      // Already in a non-Latin script: leave it as the user wrote it.
      if (!RegExp(r'[a-z]').hasMatch(token)) {
        out.add(token);
        continue;
      }
      return null; // an unknown English word: do not produce a half-translation
    }
    return translated == 0 ? null : out.join(' ');
  }

  static String _stripPlural(String word) =>
      word.length > 3 && word.endsWith('s')
          ? word.substring(0, word.length - 1)
          : word;

  // ───────────────────────────────────────────────────────────────────────────
  // Units
  // ───────────────────────────────────────────────────────────────────────────

  /// Order: te, hi, ta, kn, ml, mr, bn, gu, pa.
  static const Map<String, List<String>> _units = {
    'kg': ['కిలో', 'किलो', 'கிலோ', 'ಕಿಲೋ', 'കിലോ', 'किलो', 'কেজি', 'કિલો', 'ਕਿਲੋ'],
    'g': ['గ్రా', 'ग्राम', 'கிராம்', 'ಗ್ರಾಂ', 'ഗ്രാം', 'ग्रॅम', 'গ্রাম', 'ગ્રામ', 'ਗ੍ਰਾਮ'],
    'l': ['లీటర్', 'लीटर', 'லிட்டர்', 'ಲೀಟರ್', 'ലിറ്റർ', 'लिटर', 'লিটার', 'લિટર', 'ਲੀਟਰ'],
    'ml': ['మి.లీ', 'मि.ली', 'மி.லி', 'ಮಿ.ಲೀ', 'മി.ലി', 'मि.ली', 'মি.লি', 'મિ.લી', 'ਮਿ.ਲੀ'],
    'pc': ['పీస్', 'पीस', 'துண்டு', 'ಪೀಸ್', 'പീസ്', 'नग', 'পিস', 'નંગ', 'ਪੀਸ'],
    'pkt': ['ప్యాకెట్', 'पैकेट', 'பாக்கெட்', 'ಪ್ಯಾಕೆಟ್', 'പാക്കറ്റ്', 'पॅकेट', 'প্যাকেট', 'પેકેટ', 'ਪੈਕੇਟ'],
    'btl': ['బాటిల్', 'बोतल', 'பாட்டில்', 'ಬಾಟಲ್', 'കുപ്പി', 'बाटली', 'বোতল', 'બોટલ', 'ਬੋਤਲ'],
    'box': ['బాక్స్', 'डिब्बा', 'பெட்டி', 'ಬಾಕ್ಸ್', 'പെട്ടി', 'बॉक्स', 'বাক্স', 'બોક્સ', 'ਡੱਬਾ'],
    'doz': ['డజను', 'दर्जन', 'டஜன்', 'ಡಜನ್', 'ഡസൻ', 'डझन', 'ডজন', 'ડઝન', 'ਦਰਜਨ'],
  };

  static const Map<String, String> _unitAliases = {
    'kilo': 'kg', 'kilos': 'kg', 'kilogram': 'kg', 'kilograms': 'kg',
    'gm': 'g', 'gms': 'g', 'gram': 'g', 'grams': 'g',
    'litre': 'l', 'liter': 'l', 'litres': 'l', 'liters': 'l', 'ltr': 'l',
    'piece': 'pc', 'pieces': 'pc', 'pcs': 'pc', 'nos': 'pc',
    'packet': 'pkt', 'packets': 'pkt', 'pack': 'pkt',
    'bottle': 'btl', 'bottles': 'btl',
    'dozen': 'doz',
  };

  /// Display label for a unit such as `kg` or `pc`. Unknown units, English
  /// and unsupported languages return the unit unchanged.
  static String unit(String unit, String languageCode) {
    final column = _langs.indexOf(_base(languageCode));
    if (column < 0) return unit;
    final lower = unit.trim().toLowerCase();
    final key = _unitAliases[lower] ?? lower;
    final row = _units[key];
    return row == null ? unit : row[column];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Warnings
  // ───────────────────────────────────────────────────────────────────────────

  /// Localised version of a known voice-billing warning sentence, or null when
  /// the sentence is not one of the known ones (then use the translator).
  ///
  /// The English sentences are produced by the app (voice_billing_assistant);
  /// they are matched here by pattern so the stored/English text and all logic
  /// that compares it stay untouched.
  static String? warning(String english, String languageCode) {
    final lang = _base(languageCode);
    final column = _langs.indexOf(lang);
    if (column < 0) return null;
    final text = english.trim();

    for (final rule in _warningRules) {
      final m = rule.pattern.firstMatch(text);
      if (m == null) continue;
      final template = _warningTemplates[rule.key]![column];
      var name = '';
      var value = '';
      if (rule.nameGroup != null) {
        final raw = m.group(rule.nameGroup!) ?? '';
        name = rule.rawName ? raw : (productName(raw, languageCode) ?? raw);
      }
      if (rule.valueGroup != null) value = m.group(rule.valueGroup!) ?? '';
      return template.replaceAll('{name}', name).replaceAll('{value}', value);
    }
    return null;
  }

  static final List<_WarningRule> _warningRules = [
    _WarningRule(
      RegExp(r'^"(.+)" is not in this shop catalogue\. It can be billed as a custom item with no stock deduction; verify its name and price\.$'),
      'custom_priced', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^"(.+)" is not in this shop catalogue and no price was detected\.'),
      'custom_noprice', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^Please repeat or manually select "(.+)"; I could not safely verify it\.$'),
      'unverified', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^The AI product name "(.+)" conflicts with its catalogue ID\.'),
      'id_unknown', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^The AI returned an unknown catalogue ID for "(.+)"\.'),
      'id_unknown', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^A spoken hundred-scale amount was normalized\.'),
      'scale_normalized',
    ),
    _WarningRule(
      RegExp(r'^Corrected a spoken hundred-scale amount'),
      'scale_normalized',
    ),
    _WarningRule(
      RegExp(r'^Spoken amount "(.+)" was read as (\d+)\. Please verify\.$'),
      'number_repaired', nameGroup: 1, valueGroup: 2, rawName: true,
    ),
    _WarningRule(
      RegExp(r'GROQ_API_KEY|not configured', caseSensitive: false),
      'not_configured',
    ),
    _WarningRule(
      RegExp(r'^Groq could not verify|^Groq is unreachable|^Groq voice billing returned'),
      'verify_failed',
    ),
    _WarningRule(
      RegExp(r'^I could not confidently identify bill items\.'),
      'no_items',
    ),
    _WarningRule(
      RegExp(r'^Voice processing failed\.'),
      'processing_failed',
    ),
    _WarningRule(
      RegExp(r'^Enter a positive selling price for "(.+)" before adding it to the bill\.$'),
      'need_price', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^Review "(.+)" and its price before adding it as a custom bill item\.$'),
      'review_custom', nameGroup: 1,
    ),
    _WarningRule(
      RegExp(r'^Custom bill item: no inventory stock will be deducted\.$'),
      'custom_note',
    ),
    _WarningRule(
      RegExp(r'^Price recovered from the normalized spoken amount\.'),
      'price_recovered',
    ),
  ];

  /// Order: te, hi, ta, kn, ml, mr, bn, gu, pa.
  static const Map<String, List<String>> _warningTemplates = {
    'custom_priced': [
      '"{name}" మీ దుకాణ కేటలాగ్‌లో లేదు. దీనిని కస్టమ్ వస్తువుగా బిల్ చేస్తాం, స్టాక్ తగ్గదు. పేరు, ధరను తనిఖీ చేయండి.',
      '"{name}" आपकी दुकान की सूची में नहीं है। इसे कस्टम आइटम के रूप में बिल किया जाएगा और स्टॉक कम नहीं होगा। नाम और कीमत जाँचें।',
      '"{name}" உங்கள் கடை பட்டியலில் இல்லை. இது தனிப்பயன் பொருளாக பில் செய்யப்படும்; ஸ்டாக் குறையாது. பெயர், விலையைச் சரிபார்க்கவும்.',
      '"{name}" ನಿಮ್ಮ ಅಂಗಡಿಯ ಪಟ್ಟಿಯಲ್ಲಿ ಇಲ್ಲ. ಇದನ್ನು ಕಸ್ಟಮ್ ವಸ್ತುವಾಗಿ ಬಿಲ್ ಮಾಡಲಾಗುತ್ತದೆ; ಸ್ಟಾಕ್ ಕಡಿಮೆಯಾಗುವುದಿಲ್ಲ. ಹೆಸರು ಮತ್ತು ಬೆಲೆ ಪರಿಶೀಲಿಸಿ.',
      '"{name}" നിങ്ങളുടെ കടയുടെ പട്ടികയിൽ ഇല്ല. ഇത് കസ്റ്റം ഇനമായി ബിൽ ചെയ്യും; സ്റ്റോക്ക് കുറയില്ല. പേരും വിലയും പരിശോധിക്കുക.',
      '"{name}" तुमच्या दुकानाच्या यादीत नाही. हे कस्टम वस्तू म्हणून बिल केले जाईल; स्टॉक कमी होणार नाही. नाव आणि किंमत तपासा.',
      '"{name}" আপনার দোকানের তালিকায় নেই। এটি কাস্টম আইটেম হিসেবে বিল হবে; স্টক কমবে না। নাম ও দাম যাচাই করুন।',
      '"{name}" તમારી દુકાનની યાદીમાં નથી. તેને કસ્ટમ વસ્તુ તરીકે બિલ કરવામાં આવશે; સ્ટોક ઘટશે નહીં. નામ અને કિંમત તપાસો.',
      '"{name}" ਤੁਹਾਡੀ ਦੁਕਾਨ ਦੀ ਸੂਚੀ ਵਿੱਚ ਨਹੀਂ ਹੈ। ਇਹ ਕਸਟਮ ਆਈਟਮ ਵਜੋਂ ਬਿਲ ਹੋਵੇਗੀ; ਸਟਾਕ ਘਟੇਗਾ ਨਹੀਂ। ਨਾਮ ਅਤੇ ਕੀਮਤ ਜਾਂਚੋ।',
    ],
    'custom_noprice': [
      '"{name}" మీ దుకాణ కేటలాగ్‌లో లేదు, ధర కూడా వినిపించలేదు. పేరును తనిఖీ చేసి ధర నమోదు చేయండి. స్టాక్ తగ్గదు.',
      '"{name}" आपकी दुकान की सूची में नहीं है और कीमत सुनाई नहीं दी। नाम जाँचें और कीमत दर्ज करें। स्टॉक कम नहीं होगा।',
      '"{name}" உங்கள் கடை பட்டியலில் இல்லை, விலையும் கேட்கவில்லை. பெயரைச் சரிபார்த்து விலையை உள்ளிடவும். ஸ்டாக் குறையாது.',
      '"{name}" ನಿಮ್ಮ ಅಂಗಡಿಯ ಪಟ್ಟಿಯಲ್ಲಿ ಇಲ್ಲ, ಬೆಲೆಯೂ ಕೇಳಿಸಲಿಲ್ಲ. ಹೆಸರು ಪರಿಶೀಲಿಸಿ ಬೆಲೆ ನಮೂದಿಸಿ. ಸ್ಟಾಕ್ ಕಡಿಮೆಯಾಗುವುದಿಲ್ಲ.',
      '"{name}" നിങ്ങളുടെ കടയുടെ പട്ടികയിൽ ഇല്ല, വിലയും കേട്ടില്ല. പേര് പരിശോധിച്ച് വില നൽകുക. സ്റ്റോക്ക് കുറയില്ല.',
      '"{name}" तुमच्या दुकानाच्या यादीत नाही आणि किंमत ऐकू आली नाही. नाव तपासा आणि किंमत टाका. स्टॉक कमी होणार नाही.',
      '"{name}" আপনার দোকানের তালিকায় নেই এবং দাম শোনা যায়নি। নাম যাচাই করে দাম লিখুন। স্টক কমবে না।',
      '"{name}" તમારી દુકાનની યાદીમાં નથી અને કિંમત સંભળાઈ નથી. નામ તપાસો અને કિંમત દાખલ કરો. સ્ટોક ઘટશે નહીં.',
      '"{name}" ਤੁਹਾਡੀ ਦੁਕਾਨ ਦੀ ਸੂਚੀ ਵਿੱਚ ਨਹੀਂ ਹੈ ਅਤੇ ਕੀਮਤ ਸੁਣਾਈ ਨਹੀਂ ਦਿੱਤੀ। ਨਾਮ ਜਾਂਚੋ ਅਤੇ ਕੀਮਤ ਦਾਖ਼ਲ ਕਰੋ। ਸਟਾਕ ਘਟੇਗਾ ਨਹੀਂ।',
    ],
    'unverified': [
      '"{name}" ను మళ్లీ చెప్పండి లేదా చేతితో ఎంచుకోండి; నేను దీన్ని ధృవీకరించలేకపోయాను.',
      '"{name}" दोबारा बोलें या हाथ से चुनें; मैं इसकी पुष्टि नहीं कर सका।',
      '"{name}" என்பதை மீண்டும் சொல்லுங்கள் அல்லது கையால் தேர்ந்தெடுக்கவும்; என்னால் உறுதிசெய்ய முடியவில்லை.',
      '"{name}" ಅನ್ನು ಮತ್ತೆ ಹೇಳಿ ಅಥವಾ ಕೈಯಾರೆ ಆಯ್ಕೆಮಾಡಿ; ನನಗೆ ಖಚಿತಪಡಿಸಲು ಆಗಲಿಲ್ಲ.',
      '"{name}" വീണ്ടും പറയുക അല്ലെങ്കിൽ കൈകൊണ്ട് തിരഞ്ഞെടുക്കുക; എനിക്ക് ഉറപ്പാക്കാനായില്ല.',
      '"{name}" पुन्हा सांगा किंवा हाताने निवडा; मला खात्री करता आली नाही.',
      '"{name}" আবার বলুন বা হাতে বেছে নিন; আমি নিশ্চিত হতে পারিনি।',
      '"{name}" ફરી બોલો અથવા હાથથી પસંદ કરો; હું ખાતરી કરી શક્યો નથી.',
      '"{name}" ਦੁਬਾਰਾ ਬੋਲੋ ਜਾਂ ਹੱਥ ਨਾਲ ਚੁਣੋ; ਮੈਂ ਪੁਸ਼ਟੀ ਨਹੀਂ ਕਰ ਸਕਿਆ।',
    ],
    'id_unknown': [
      '"{name}" ను మీ కేటలాగ్‌తో సరిపోల్చలేకపోయాం. సరైన వస్తువును చేతితో ఎంచుకోండి. స్టాక్ తగ్గదు.',
      '"{name}" को आपकी सूची से मिलाया नहीं जा सका। सही वस्तु हाथ से चुनें। स्टॉक कम नहीं होगा।',
      '"{name}" உங்கள் பட்டியலுடன் பொருந்தவில்லை. சரியான பொருளை கையால் தேர்ந்தெடுக்கவும். ஸ்டாக் குறையாது.',
      '"{name}" ಅನ್ನು ನಿಮ್ಮ ಪಟ್ಟಿಯೊಂದಿಗೆ ಹೊಂದಿಸಲಾಗಲಿಲ್ಲ. ಸರಿಯಾದ ವಸ್ತುವನ್ನು ಕೈಯಾರೆ ಆಯ್ಕೆಮಾಡಿ. ಸ್ಟಾಕ್ ಕಡಿಮೆಯಾಗುವುದಿಲ್ಲ.',
      '"{name}" നിങ്ങളുടെ പട്ടികയുമായി പൊരുത്തപ്പെടുത്താനായില്ല. ശരിയായ ഇനം കൈകൊണ്ട് തിരഞ്ഞെടുക്കുക. സ്റ്റോക്ക് കുറയില്ല.',
      '"{name}" तुमच्या यादीशी जुळवता आले नाही. योग्य वस्तू हाताने निवडा. स्टॉक कमी होणार नाही.',
      '"{name}" আপনার তালিকার সাথে মেলানো যায়নি। সঠিক পণ্যটি হাতে বেছে নিন। স্টক কমবে না।',
      '"{name}" ને તમારી યાદી સાથે મેળવી શકાયું નથી. સાચી વસ્તુ હાથથી પસંદ કરો. સ્ટોક ઘટશે નહીં.',
      '"{name}" ਨੂੰ ਤੁਹਾਡੀ ਸੂਚੀ ਨਾਲ ਮਿਲਾਇਆ ਨਹੀਂ ਜਾ ਸਕਿਆ। ਸਹੀ ਚੀਜ਼ ਹੱਥ ਨਾਲ ਚੁਣੋ। ਸਟਾਕ ਘਟੇਗਾ ਨਹੀਂ।',
    ],
    'scale_normalized': [
      'వందల్లో చెప్పిన మొత్తాన్ని సంఖ్యగా మార్చాం. వస్తువు, ధరను తనిఖీ చేయండి.',
      'सैकड़ों में बोली गई रकम को संख्या में बदला गया। वस्तु और कीमत जाँचें।',
      'நூற்றுக்கணக்கில் சொன்ன தொகை எண்ணாக மாற்றப்பட்டது. பொருள், விலையைச் சரிபார்க்கவும்.',
      'ನೂರರಲ್ಲಿ ಹೇಳಿದ ಮೊತ್ತವನ್ನು ಸಂಖ್ಯೆಯಾಗಿ ಬದಲಾಯಿಸಲಾಗಿದೆ. ವಸ್ತು ಮತ್ತು ಬೆಲೆ ಪರಿಶೀಲಿಸಿ.',
      'നൂറുകളിൽ പറഞ്ഞ തുക സംഖ്യയാക്കി മാറ്റി. ഇനവും വിലയും പരിശോധിക്കുക.',
      'शेकड्यात सांगितलेली रक्कम संख्येत बदलली. वस्तू आणि किंमत तपासा.',
      'শ-এ বলা অঙ্ক সংখ্যায় পরিবর্তন করা হয়েছে। পণ্য ও দাম যাচাই করুন।',
      'સોમાં બોલાયેલી રકમને સંખ્યામાં બદલવામાં આવી છે. વસ્તુ અને કિંમત તપાસો.',
      'ਸੈਂਕੜਿਆਂ ਵਿੱਚ ਬੋਲੀ ਰਕਮ ਨੂੰ ਗਿਣਤੀ ਵਿੱਚ ਬਦਲਿਆ ਗਿਆ। ਚੀਜ਼ ਅਤੇ ਕੀਮਤ ਜਾਂਚੋ।',
    ],
    'number_repaired': [
      'మీరు "{name}" అన్నారు; దీన్ని {value} గా అర్థం చేసుకున్నాం. దయచేసి తనిఖీ చేయండి.',
      'आपने "{name}" कहा; इसे {value} पढ़ा गया। कृपया जाँचें।',
      'நீங்கள் "{name}" என்றீர்கள்; அது {value} என எடுத்துக்கொள்ளப்பட்டது. தயவுசெய்து சரிபார்க்கவும்.',
      'ನೀವು "{name}" ಎಂದಿರಿ; ಅದನ್ನು {value} ಎಂದು ಓದಲಾಗಿದೆ. ದಯವಿಟ್ಟು ಪರಿಶೀಲಿಸಿ.',
      'നിങ്ങൾ "{name}" എന്ന് പറഞ്ഞു; അത് {value} ആയി വായിച്ചു. ദയവായി പരിശോധിക്കുക.',
      'तुम्ही "{name}" म्हणालात; ते {value} असे वाचले गेले. कृपया तपासा.',
      'আপনি "{name}" বলেছেন; এটি {value} হিসেবে পড়া হয়েছে। অনুগ্রহ করে যাচাই করুন।',
      'તમે "{name}" કહ્યું; તેને {value} તરીકે વાંચવામાં આવ્યું. કૃપા કરીને તપાસો.',
      'ਤੁਸੀਂ "{name}" ਕਿਹਾ; ਇਹ {value} ਪੜ੍ਹਿਆ ਗਿਆ। ਕਿਰਪਾ ਕਰਕੇ ਜਾਂਚੋ।',
    ],
    'verify_failed': [
      'వాయిస్ బిల్లింగ్ ఈ అభ్యర్థనను ధృవీకరించలేకపోయింది. ఏ వస్తువులూ చేర్చలేదు. మళ్లీ ప్రయత్నించండి లేదా చేతితో నమోదు చేయండి.',
      'वॉइस बिलिंग इस अनुरोध की पुष्टि नहीं कर सकी। कोई वस्तु नहीं जोड़ी गई। फिर कोशिश करें या हाथ से दर्ज करें।',
      'குரல் பில்லிங் இந்தக் கோரிக்கையை உறுதிசெய்ய முடியவில்லை. எந்தப் பொருளும் சேர்க்கப்படவில்லை. மீண்டும் முயலவும் அல்லது கையால் உள்ளிடவும்.',
      'ಧ್ವನಿ ಬಿಲ್ಲಿಂಗ್ ಈ ವಿನಂತಿಯನ್ನು ಖಚಿತಪಡಿಸಲು ಆಗಲಿಲ್ಲ. ಯಾವುದೇ ವಸ್ತು ಸೇರಿಸಿಲ್ಲ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ ಅಥವಾ ಕೈಯಾರೆ ನಮೂದಿಸಿ.',
      'വോയ്സ് ബില്ലിംഗിന് ഈ അഭ്യർത്ഥന ഉറപ്പാക്കാനായില്ല. ഒരു ഇനവും ചേർത്തില്ല. വീണ്ടും ശ്രമിക്കുക അല്ലെങ്കിൽ കൈകൊണ്ട് നൽകുക.',
      'व्हॉइस बिलिंग या विनंतीची खात्री करू शकले नाही. कोणतीही वस्तू जोडली नाही. पुन्हा प्रयत्न करा किंवा हाताने टाका.',
      'ভয়েস বিলিং এই অনুরোধ যাচাই করতে পারেনি। কোনো পণ্য যোগ হয়নি। আবার চেষ্টা করুন বা হাতে লিখুন।',
      'વોઇસ બિલિંગ આ વિનંતીની ખાતરી કરી શક્યું નથી. કોઈ વસ્તુ ઉમેરી નથી. ફરી પ્રયાસ કરો અથવા હાથથી દાખલ કરો.',
      'ਵੌਇਸ ਬਿਲਿੰਗ ਇਸ ਬੇਨਤੀ ਦੀ ਪੁਸ਼ਟੀ ਨਹੀਂ ਕਰ ਸਕੀ। ਕੋਈ ਚੀਜ਼ ਨਹੀਂ ਜੋੜੀ ਗਈ। ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ ਜਾਂ ਹੱਥ ਨਾਲ ਦਾਖ਼ਲ ਕਰੋ।',
    ],
    'not_configured': [
      'వాయిస్ బిల్లింగ్ ప్రస్తుతం అందుబాటులో లేదు. ఏ వస్తువులూ చేర్చలేదు. దయచేసి సపోర్ట్‌ను సంప్రదించండి.',
      'वॉइस बिलिंग अभी उपलब्ध नहीं है। कोई वस्तु नहीं जोड़ी गई। कृपया सहायता से संपर्क करें।',
      'குரல் பில்லிங் தற்போது கிடைக்கவில்லை. எந்தப் பொருளும் சேர்க்கப்படவில்லை. ஆதரவைத் தொடர்புகொள்ளவும்.',
      'ಧ್ವನಿ ಬಿಲ್ಲಿಂಗ್ ಈಗ ಲಭ್ಯವಿಲ್ಲ. ಯಾವುದೇ ವಸ್ತು ಸೇರಿಸಿಲ್ಲ. ದಯವಿಟ್ಟು ಬೆಂಬಲವನ್ನು ಸಂಪರ್ಕಿಸಿ.',
      'വോയ്സ് ബില്ലിംഗ് ഇപ്പോൾ ലഭ്യമല്ല. ഒരു ഇനവും ചേർത്തില്ല. ദയവായി സപ്പോർട്ടിനെ ബന്ധപ്പെടുക.',
      'व्हॉइस बिलिंग सध्या उपलब्ध नाही. कोणतीही वस्तू जोडली नाही. कृपया सपोर्टशी संपर्क साधा.',
      'ভয়েস বিলিং এখন উপলব্ধ নয়। কোনো পণ্য যোগ হয়নি। অনুগ্রহ করে সাপোর্টে যোগাযোগ করুন।',
      'વોઇસ બિલિંગ હાલ ઉપલબ્ધ નથી. કોઈ વસ્તુ ઉમેરી નથી. કૃપા કરીને સપોર્ટનો સંપર્ક કરો.',
      'ਵੌਇਸ ਬਿਲਿੰਗ ਹੁਣ ਉਪਲਬਧ ਨਹੀਂ ਹੈ। ਕੋਈ ਚੀਜ਼ ਨਹੀਂ ਜੋੜੀ ਗਈ। ਕਿਰਪਾ ਕਰਕੇ ਸਹਾਇਤਾ ਨਾਲ ਸੰਪਰਕ ਕਰੋ।',
    ],
    'no_items': [
      'ఏ వస్తువులనూ నమ్మకంగా గుర్తించలేకపోయాను. నేను విన్నది తనిఖీ చేయండి.',
      'मैं किसी वस्तु को भरोसे से पहचान नहीं सका। जो मैंने सुना उसे जाँचें।',
      'எந்தப் பொருளையும் உறுதியாக அடையாளம் காண முடியவில்லை. நான் கேட்டதைச் சரிபார்க்கவும்.',
      'ಯಾವುದೇ ವಸ್ತುವನ್ನು ವಿಶ್ವಾಸದಿಂದ ಗುರುತಿಸಲಾಗಲಿಲ್ಲ. ನಾನು ಕೇಳಿದ್ದನ್ನು ಪರಿಶೀಲಿಸಿ.',
      'ഒരു ഇനവും ഉറപ്പോടെ തിരിച്ചറിയാനായില്ല. ഞാൻ കേട്ടത് പരിശോധിക്കുക.',
      'मी कोणतीही वस्तू खात्रीने ओळखू शकलो नाही. मी जे ऐकले ते तपासा.',
      'আমি কোনো পণ্য নিশ্চিতভাবে চিনতে পারিনি। আমি যা শুনেছি তা যাচাই করুন।',
      'હું કોઈ વસ્તુ ખાતરીથી ઓળખી શક્યો નથી. મેં જે સાંભળ્યું તે તપાસો.',
      'ਮੈਂ ਕੋਈ ਚੀਜ਼ ਭਰੋਸੇ ਨਾਲ ਪਛਾਣ ਨਹੀਂ ਸਕਿਆ। ਜੋ ਮੈਂ ਸੁਣਿਆ ਉਸਨੂੰ ਜਾਂਚੋ।',
    ],
    'processing_failed': [
      'వాయిస్ ప్రాసెసింగ్ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.',
      'वॉइस प्रोसेसिंग विफल रही। कृपया फिर कोशिश करें।',
      'குரல் செயலாக்கம் தோல்வியடைந்தது. மீண்டும் முயலவும்.',
      'ಧ್ವನಿ ಪ್ರಕ್ರಿಯೆ ವಿಫಲವಾಯಿತು. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
      'വോയ്സ് പ്രോസസ്സിംഗ് പരാജയപ്പെട്ടു. ദയവായി വീണ്ടും ശ്രമിക്കുക.',
      'व्हॉइस प्रोसेसिंग अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.',
      'ভয়েস প্রসেসিং ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।',
      'વોઇસ પ્રોસેસિંગ નિષ્ફળ ગયું. કૃપા કરીને ફરી પ્રયાસ કરો.',
      'ਵੌਇਸ ਪ੍ਰੋਸੈਸਿੰਗ ਅਸਫਲ ਰਹੀ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।',
    ],
    'need_price': [
      'బిల్లులో చేర్చే ముందు "{name}" అమ్మకపు ధర నమోదు చేయండి.',
      'बिल में जोड़ने से पहले "{name}" की बिक्री कीमत दर्ज करें।',
      'பில்லில் சேர்க்கும் முன் "{name}" விற்பனை விலையை உள்ளிடவும்.',
      'ಬಿಲ್‌ಗೆ ಸೇರಿಸುವ ಮೊದಲು "{name}" ಮಾರಾಟ ಬೆಲೆಯನ್ನು ನಮೂದಿಸಿ.',
      'ബില്ലിൽ ചേർക്കുന്നതിന് മുമ്പ് "{name}" വിൽപ്പന വില നൽകുക.',
      'बिलात जोडण्यापूर्वी "{name}" ची विक्री किंमत टाका.',
      'বিলে যোগ করার আগে "{name}" এর বিক্রয় মূল্য লিখুন।',
      'બિલમાં ઉમેરતા પહેલાં "{name}" ની વેચાણ કિંમત દાખલ કરો.',
      'ਬਿਲ ਵਿੱਚ ਜੋੜਨ ਤੋਂ ਪਹਿਲਾਂ "{name}" ਦੀ ਵਿਕਰੀ ਕੀਮਤ ਦਾਖ਼ਲ ਕਰੋ।',
    ],
    'review_custom': [
      '"{name}" మరియు దాని ధరను తనిఖీ చేసి, కస్టమ్ వస్తువుగా చేర్చండి.',
      '"{name}" और उसकी कीमत जाँचकर इसे कस्टम आइटम के रूप में जोड़ें।',
      '"{name}" மற்றும் அதன் விலையைச் சரிபார்த்து தனிப்பயன் பொருளாகச் சேர்க்கவும்.',
      '"{name}" ಮತ್ತು ಅದರ ಬೆಲೆಯನ್ನು ಪರಿಶೀಲಿಸಿ ಕಸ್ಟಮ್ ವಸ್ತುವಾಗಿ ಸೇರಿಸಿ.',
      '"{name}" ഉം അതിന്റെ വിലയും പരിശോധിച്ച് കസ്റ്റം ഇനമായി ചേർക്കുക.',
      '"{name}" आणि त्याची किंमत तपासून कस्टम वस्तू म्हणून जोडा.',
      '"{name}" ও তার দাম যাচাই করে কাস্টম আইটেম হিসেবে যোগ করুন।',
      '"{name}" અને તેની કિંમત તપાસીને કસ્ટમ વસ્તુ તરીકે ઉમેરો.',
      '"{name}" ਅਤੇ ਇਸਦੀ ਕੀਮਤ ਜਾਂਚ ਕੇ ਕਸਟਮ ਆਈਟਮ ਵਜੋਂ ਜੋੜੋ।',
    ],
    'custom_note': [
      'కస్టమ్ వస్తువు: స్టాక్ తగ్గదు.',
      'कस्टम आइटम: स्टॉक कम नहीं होगा।',
      'தனிப்பயன் பொருள்: ஸ்டாக் குறையாது.',
      'ಕಸ್ಟಮ್ ವಸ್ತು: ಸ್ಟಾಕ್ ಕಡಿಮೆಯಾಗುವುದಿಲ್ಲ.',
      'കസ്റ്റം ഇനം: സ്റ്റോക്ക് കുറയില്ല.',
      'कस्टम वस्तू: स्टॉक कमी होणार नाही.',
      'কাস্টম আইটেম: স্টক কমবে না।',
      'કસ્ટમ વસ્તુ: સ્ટોક ઘટશે નહીં.',
      'ਕਸਟਮ ਆਈਟਮ: ਸਟਾਕ ਘਟੇਗਾ ਨਹੀਂ।',
    ],
    'price_recovered': [
      'మీరు చెప్పిన మొత్తం నుండి ధర తీసుకున్నాం. బిల్లింగ్ ముందు తనిఖీ చేయండి.',
      'कीमत आपकी बोली गई रकम से ली गई है। बिलिंग से पहले जाँचें।',
      'நீங்கள் சொன்ன தொகையிலிருந்து விலை எடுக்கப்பட்டது. பில்லிங்கிற்கு முன் சரிபார்க்கவும்.',
      'ನೀವು ಹೇಳಿದ ಮೊತ್ತದಿಂದ ಬೆಲೆ ಪಡೆಯಲಾಗಿದೆ. ಬಿಲ್ಲಿಂಗ್ ಮೊದಲು ಪರಿಶೀಲಿಸಿ.',
      'നിങ്ങൾ പറഞ്ഞ തുകയിൽ നിന്ന് വില എടുത്തു. ബില്ലിംഗിന് മുമ്പ് പരിശോധിക്കുക.',
      'तुम्ही सांगितलेल्या रकमेवरून किंमत घेतली आहे. बिलिंगपूर्वी तपासा.',
      'আপনার বলা অঙ্ক থেকে দাম নেওয়া হয়েছে। বিলিংয়ের আগে যাচাই করুন।',
      'તમે કહેલી રકમ પરથી કિંમત લેવામાં આવી છે. બિલિંગ પહેલાં તપાસો.',
      'ਕੀਮਤ ਤੁਹਾਡੀ ਬੋਲੀ ਰਕਮ ਤੋਂ ਲਈ ਗਈ ਹੈ। ਬਿਲਿੰਗ ਤੋਂ ਪਹਿਲਾਂ ਜਾਂਚੋ।',
    ],
  };

  /// Display-only live line while the shopkeeper is speaking.
  static String liveTypedPreview(String spoken, String languageCode) {
    final trimmed = spoken.trim();
    if (trimmed.isEmpty) return '';
    final whole = productName(trimmed, languageCode);
    if (whole != null) return whole;
    return trimmed
        .split(RegExp(r'\s*,\s*'))
        .map((chunk) => productName(chunk, languageCode) ?? chunk.trim())
        .where((chunk) => chunk.isNotEmpty)
        .join(', ');
  }
}

class _WarningRule {
  _WarningRule(
    this.pattern,
    this.key, {
    this.nameGroup,
    this.valueGroup,
    this.rawName = false,
  });
  final RegExp pattern;
  final String key;
  final int? nameGroup;
  final int? valueGroup;

  /// When true the captured text is spoken words, not a product name, so it is
  /// shown as heard instead of being looked up in the product dictionary.
  final bool rawName;
}
